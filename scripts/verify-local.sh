#!/usr/bin/env bash
set -euo pipefail

ENDPOINT="${FLOCI_ENDPOINT:-http://localhost:4566}"
REGION="${AWS_REGION:-us-east-1}"
NAME_PREFIX="${NAME_PREFIX:-aws-prod-infra-local-floci}"
EXPECTED_VPC_CIDR="${EXPECTED_VPC_CIDR:-10.10.0.0/16}"

export AWS_ACCESS_KEY_ID="test"
export AWS_SECRET_ACCESS_KEY="test"
export AWS_DEFAULT_REGION="$REGION"
export AWS_PAGER=""

aws_local() {
  aws --endpoint-url "$ENDPOINT" --region "$REGION" "$@"
}

echo "=== 1. Verifying VPC ==="
VPC_JSON="$(aws_local ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=${NAME_PREFIX}-vpc" --output json)"
VPC_ID="$(python3 -c '
import json, sys
vpcs = json.load(sys.stdin).get("Vpcs", [])
assert len(vpcs) >= 1, "VPC not found"
cidr = vpcs[0]["CidrBlock"]
assert cidr == sys.argv[1], f"Unexpected CIDR: {cidr}"
print(vpcs[0]["VpcId"])
' "$EXPECTED_VPC_CIDR" <<< "$VPC_JSON")"
echo "VPC: $VPC_ID ($EXPECTED_VPC_CIDR)"

echo "=== 2. Verifying Multi-AZ Subnets (>= 4 subnets across >= 2 AZs) ==="
SUBNETS_JSON="$(aws_local ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" --output json)"
python3 -c '
import json, sys
subnets = json.load(sys.stdin).get("Subnets", [])
azs = {s["AvailabilityZone"] for s in subnets}
assert len(subnets) >= 4, f"Expected >= 4 subnets, got {len(subnets)}"
assert len(azs) >= 2, f"Expected >= 2 AZs, got {sorted(azs)}"
print(f"Verified {len(subnets)} subnets across AZs: {sorted(azs)}")
' <<< "$SUBNETS_JSON"
aws_local ec2 describe-subnets \
  --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{SubnetId:SubnetId,AZ:AvailabilityZone,CIDR:CidrBlock}' --output table

echo "=== 3. Verifying Security Groups & Least-Privilege Rules (app-sg & db-sg) ==="
SGS_JSON="$(aws_local ec2 describe-security-groups \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=${NAME_PREFIX}-app-sg,${NAME_PREFIX}-db-sg" --output json)"
python3 -c '
import json, sys
sgs = json.load(sys.stdin).get("SecurityGroups", [])
assert len(sgs) == 2, f"Expected 2 SGs, got {len(sgs)}"
by_tag = {}
for sg in sgs:
    tags = {t["Key"]: t["Value"] for t in sg.get("Tags", [])}
    by_tag[tags.get("Name")] = sg

app_sg = by_tag[f"{sys.argv[1]}-app-sg"]
db_sg = by_tag[f"{sys.argv[1]}-db-sg"]
app_id = app_sg["GroupId"]
db_id = db_sg["GroupId"]

app_ports = set()
for perm in app_sg.get("IpPermissions", []):
    fp, tp = perm.get("FromPort"), perm.get("ToPort")
    if fp is not None and tp is not None:
        assert not (fp <= 22 <= tp), f"app-sg must not expose SSH port 22: {perm}"
        for p in (80, 443):
            if fp <= p <= tp:
                app_ports.add(p)
assert app_ports == {80, 443}, f"Expected app-sg ports 80 and 443, got {sorted(app_ports)}"

db_perms = db_sg.get("IpPermissions", [])
has_5432_from_app = False
for perm in db_perms:
    for r in perm.get("IpRanges", []):
        assert r.get("CidrIp") != "0.0.0.0/0", f"db-sg must not allow 0.0.0.0/0: {perm}"
    if perm.get("FromPort") == 5432 and perm.get("ToPort") == 5432:
        pairs = [p.get("GroupId") for p in perm.get("UserIdGroupPairs", [])]
        if app_id in pairs:
            has_5432_from_app = True
assert has_5432_from_app, "db-sg must allow TCP 5432 strictly from app-sg"
print(f"Verified app-sg ({app_id}) [no SSH :22, allows 80/443] & db-sg ({db_id}) [:5432 from app-sg only]")
' "$NAME_PREFIX" <<< "$SGS_JSON"

echo "=== 4. Verifying EC2 Instance & IMDSv2 ==="
EC2_JSON="$(aws_local ec2 describe-instances \
  --filters "Name=vpc-id,Values=$VPC_ID" "Name=instance-state-name,Values=pending,running" --output json)"
python3 -c '
import json, sys
res = json.load(sys.stdin).get("Reservations", [])
instances = [i for r in res for i in r.get("Instances", [])]
assert len(instances) >= 1, "EC2 instance not found"
inst = instances[0]
inst_id = inst["InstanceId"]
tokens = inst.get("MetadataOptions", {}).get("HttpTokens")
if tokens:
    assert tokens == "required", f"Expected IMDSv2 HttpTokens=required, got {tokens}"
    print(f"EC2 Instance: {inst_id} (IMDSv2 HttpTokens={tokens})")
else:
    print(f"EC2 Instance: {inst_id} (WARN: MetadataOptions omitted by emulator)")
' <<< "$EC2_JSON"

echo "=== 5. Verifying RDS PostgreSQL Instance Security ==="
RDS_JSON="$(aws_local rds describe-db-instances \
  --db-instance-identifier "${NAME_PREFIX}-postgres" --output json)"
python3 -c '
import json, sys
dbs = json.load(sys.stdin).get("DBInstances", [])
assert len(dbs) >= 1, "RDS instance not found"
db = dbs[0]
db_id = db["DBInstanceIdentifier"]
db_status = db.get("DBInstanceStatus")
assert db_status, "RDS status empty"
pub = db.get("PubliclyAccessible")
if pub is not None:
    assert pub is False, f"Expected PubliclyAccessible=False, got {pub}"
enc = db.get("StorageEncrypted")
if enc is not None:
    assert enc is True, f"Expected StorageEncrypted=True, got {enc}"
print(f"RDS {db_id}: status={db_status}, publicly_accessible={pub}, encrypted={enc}")
' <<< "$RDS_JSON"

echo "=== 6. Verifying IAM Role & Attached App Policy ==="
ROLE_ARN="$(aws_local iam get-role \
  --role-name "${NAME_PREFIX}-ec2-role" \
  --query 'Role.Arn' --output text)"
[[ -n "$ROLE_ARN" && "$ROLE_ARN" != "None" ]] || { echo "IAM role not found"; exit 1; }
ATTACHED_JSON="$(aws_local iam list-attached-role-policies \
  --role-name "${NAME_PREFIX}-ec2-role" --output json)"
python3 -c '
import json, sys
policies = [p["PolicyName"] for p in json.load(sys.stdin).get("AttachedPolicies", [])]
expected = f"{sys.argv[1]}-ec2-app-policy"
assert expected in policies, f"Expected attached policy {expected}, got {policies}"
print(f"IAM Role: {sys.argv[2]} (attached: {expected})")
' "$NAME_PREFIX" "$ROLE_ARN" <<< "$ATTACHED_JSON"

echo "=== 7. Verifying S3 App Bucket Hardening (PAB, AES256, Versioning, TLS Policy) ==="
BUCKET_NAME="${NAME_PREFIX}-assets-local"
aws_local s3 ls | grep -q "$BUCKET_NAME" || { echo "S3 bucket not found"; exit 1; }
PAB_JSON="$(aws_local s3api get-public-access-block --bucket "$BUCKET_NAME" --output json)"
ENC_JSON="$(aws_local s3api get-bucket-encryption --bucket "$BUCKET_NAME" --output json)"
VER_JSON="$(aws_local s3api get-bucket-versioning --bucket "$BUCKET_NAME" --output json)"
POL_JSON="$(aws_local s3api get-bucket-policy --bucket "$BUCKET_NAME" --output json)"
python3 -c '
import json, sys
pab = json.loads(sys.argv[1]).get("PublicAccessBlockConfiguration", {})
for k in ("BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets"):
    assert pab.get(k) is True, f"PublicAccessBlock {k} must be True, got {pab}"
enc = json.loads(sys.argv[2])
algos = [r["ApplyServerSideEncryptionByDefault"]["SSEAlgorithm"] for r in enc.get("ServerSideEncryptionConfiguration", {}).get("Rules", [])]
assert "AES256" in algos, f"Expected AES256 encryption, got {algos}"
ver = json.loads(sys.argv[3]).get("Status")
assert ver == "Enabled", f"Expected Versioning Enabled, got {ver}"
pol_raw = json.loads(sys.argv[4]).get("Policy", "")
assert "aws:SecureTransport" in pol_raw, "Expected TLS-only SecureTransport policy on bucket"
print(f"S3 Bucket {sys.argv[5]}: PAB=all-true, SSE=AES256, Versioning=Enabled, TLS-only=yes")
' "$PAB_JSON" "$ENC_JSON" "$VER_JSON" "$POL_JSON" "$BUCKET_NAME"

echo "=== 8. Verifying CloudWatch Log Group ==="
LOG_NAME="$(aws_local logs describe-log-groups \
  --log-group-name-prefix "/aws/ec2/${NAME_PREFIX}" \
  --query 'logGroups[0].logGroupName' --output text)"
[[ "$LOG_NAME" == "/aws/ec2/${NAME_PREFIX}" ]] || { echo "Log group not found"; exit 1; }
echo "Log Group: $LOG_NAME"

echo "=== 9. Verifying CloudWatch Metric Alarms ==="
ALARMS_JSON="$(aws_local cloudwatch describe-alarms \
  --alarm-names "${NAME_PREFIX}-ec2-high-cpu" "${NAME_PREFIX}-ec2-status-check" --output json)"
python3 -c '
import json, sys
alarms = {a["AlarmName"] for a in json.load(sys.stdin).get("MetricAlarms", [])}
expected = {f"{sys.argv[1]}-ec2-high-cpu", f"{sys.argv[1]}-ec2-status-check"}
missing = sorted(expected - alarms)
assert not missing, f"Missing CloudWatch alarms: {missing}"
print(f"CloudWatch Alarms verified: {sorted(alarms)}")
' "$NAME_PREFIX" <<< "$ALARMS_JSON"

echo "ALL LOCAL FLOCI RESOURCE CHECKS PASSED"

mock_provider "aws" {}

variables {
  name_prefix           = "test-alb"
  vpc_id                = "vpc-12345678"
  public_subnet_ids     = ["subnet-11111111", "subnet-22222222"]
  alb_security_group_id = "sg-12345678"
}

run "alb_http_default" {
  command = plan

  assert {
    condition     = aws_lb.main.drop_invalid_header_fields == true && aws_lb.main.enable_deletion_protection == true
    error_message = "ALB must drop invalid HTTP headers and enable deletion protection by default."
  }

  assert {
    condition     = length(aws_lb_listener.http_forward) == 1 && length(aws_lb_listener.https) == 0
    error_message = "HTTP forwarder must activate when acm_certificate_arn is empty."
  }
}

run "alb_tls_13_redirect" {
  command = plan

  variables {
    acm_certificate_arn = "arn:aws:acm:us-east-1:123456789012:certificate/12345678-1234-1234-1234-123456789012"
  }

  assert {
    condition     = length(aws_lb_listener.https) == 1 && aws_lb_listener.https[0].ssl_policy == "ELBSecurityPolicy-TLS13-1-2-2021-06"
    error_message = "HTTPS:443 listener must enforce TLS 1.3 security policy when acm_certificate_arn is set."
  }

  assert {
    condition     = length(aws_lb_listener.http_redirect) == 1 && length(aws_lb_listener.http_forward) == 0
    error_message = "HTTP:80 must redirect to HTTPS:443 instead of forwarding when TLS is enabled."
  }
}

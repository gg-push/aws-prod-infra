.PHONY: floci-up floci-down fmt validate-all lock-providers init-local plan-local apply-local verify-local destroy-local clean

TF_LOCAL_DIR := environments/local-floci
DB_PASS      ?= LocalDevPass123!

floci-up:
	docker compose -f docker-compose.floci.yml up -d
	@echo "Waiting for Floci on http://localhost:4566 ..."
	@for i in $$(seq 1 30); do \
		code="$$(curl -s -o /dev/null -w '%{http_code}' http://localhost:4566/ || echo 000)"; \
		case "$$code" in \
			[234]*) echo "Floci is reachable on :4566 (HTTP $$code)"; exit 0 ;; \
		esac; \
		sleep 1; \
	done; \
	echo "Floci did not become ready in time" >&2; exit 1

floci-down:
	docker compose -f docker-compose.floci.yml down -v

fmt:
	terraform fmt -recursive

validate-all:
	terraform fmt -check -recursive
	@for dir in bootstrap environments/local-floci environments/staging environments/prod; do \
		echo "=== Validating $$dir ==="; \
		terraform -chdir=$$dir init -backend=false -input=false >/dev/null && \
		terraform -chdir=$$dir validate; \
	done

lock-providers:
	@for dir in bootstrap environments/local-floci environments/staging environments/prod; do \
		echo "=== Locking providers in $$dir ==="; \
		terraform -chdir=$$dir providers lock -platform=linux_amd64 -platform=darwin_arm64 -platform=darwin_amd64; \
	done

init-local:
	terraform -chdir=$(TF_LOCAL_DIR) init -input=false

plan-local: init-local
	TF_VAR_db_password="$(DB_PASS)" terraform -chdir=$(TF_LOCAL_DIR) plan -input=false

apply-local: init-local
	TF_VAR_db_password="$(DB_PASS)" terraform -chdir=$(TF_LOCAL_DIR) apply -auto-approve -input=false

verify-local:
	bash scripts/verify-local.sh

destroy-local:
	TF_VAR_db_password="$(DB_PASS)" terraform -chdir=$(TF_LOCAL_DIR) destroy -auto-approve -input=false

clean:
	find . -type d -name ".terraform" -prune -exec rm -rf {} +
	find . -type f -name "*.tfstate*" -delete

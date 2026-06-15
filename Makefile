.DEFAULT_GOAL := deploy
.PHONY: deploy clean edit-secrets _init check new-service lint verify-local deps verify-templates test

# Extract remote IP from inventory
REMOTE_IP := $(shell grep ansible_host inventory/hosts.yml | awk '{print $$2}')

deps:
	@echo "==> Installing dependencies..."
	@ansible-galaxy install -r requirements.yml
	@if ! command -v molecule >/dev/null 2>&1; then \
		pipx install molecule; \
		pipx inject molecule molecule-plugins[docker] paramiko; \
	fi
	@if [ ! -d roles/mitogen ]; then \
		echo "==> Installing Mitogen..."; \
		git clone --depth 1 --branch v0.3.49 https://github.com/mitogen-hq/mitogen.git roles/mitogen; \
	fi

test: lint check verify-templates
	@echo "==> Running Role Molecule tests..."
	@$(MAKE) test-role ROLE=pre_flight
	@$(MAKE) test-role ROLE=host_cron
	@$(MAKE) test-role ROLE=filesystem
	@echo "==> All tests passed!"

check: deps
	ansible-playbook site.yml --syntax-check

# Run every pre-commit hook against every tracked file. Use before pushing
# if you've been bypassing hooks. Slower than commit-time hooks because
# nothing is cached against the index.
lint: deps
	pre-commit run --all-files

# "Poor-man's CI" — what cloud CI would run, but local. Lint, syntax-check,
# template validation, and a check-mode dry run against the live host.
verify-local: lint check verify-templates
	@echo "==> Dry-run against live host (no changes will be applied)"
	ansible-playbook site.yml --check --diff

verify-templates:
	@echo "==> Validating Docker Compose templates..."
	ansible-playbook validate-templates.yml

clean:
	@echo "==> Cleaning homelab state..."
	ansible-playbook clean.yml

# Scaffold a new service. Pass NAME and PORT (and optionally INTERNAL_PORT,
# IMAGE, USE_VPN, GROUP). Example:
#   make new-service NAME=anki PORT=8765
new-service:
	@python3 scripts/new-service.py "$(NAME)" "$(PORT)" \
	  $(if $(INTERNAL_PORT),--internal-port "$(INTERNAL_PORT)") \
	  $(if $(IMAGE),--image "$(IMAGE)") \
	  $(if $(USE_VPN),--use-vpn) \
	  $(if $(GROUP),--group "$(GROUP)")

# Run Molecule tests for a specific role. Pass ROLE. Example:
#   make test-role ROLE=host_cron
test-role: deps
	@echo "==> Testing role: $(ROLE) (using remote Docker host: $(REMOTE_IP))"
	@cd roles/$(ROLE) && DOCKER_HOST="ssh://caleb@$(REMOTE_IP)" ANSIBLE_STRATEGY=linear ANSIBLE_PIPELINING=False ANSIBLE_REMOTE_TMP=/tmp ANSIBLE_ROLES_PATH=../../.. molecule test

# Internal task to ensure Age key and .sops.yaml are ready
_init: deps
	@mkdir -p ~/.config/sops/age
	@if [ ! -f ~/.config/sops/age/keys.txt ]; then \
		echo "Generating new Age key..."; \
		age-keygen -o ~/.config/sops/age/keys.txt; \
	fi
	@PUBKEY=$$(grep -oE "age1[a-z0-9]+" ~/.config/sops/age/keys.txt); \
	if grep -q "age1\.\.\." .sops.yaml; then \
		echo "Initializing .sops.yaml with Public Key: $$PUBKEY"; \
		sed -i '' "s/age1\.\.\./$$PUBKEY/g" .sops.yaml; \
		echo "Resetting placeholder secrets file..."; \
		rm -f inventory/group_vars/all/secrets.sops.yml; \
	fi
	@if [ ! -f inventory/group_vars/all/secrets.sops.yml ]; then \
		echo "Creating fresh secrets file..."; \
		printf "vpn:\n  provider: mullvad\n  private_key: \"\"\n  addresses: \"\"" > inventory/group_vars/all/secrets.sops.yml; \
		export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt; \
		sops --encrypt --in-place inventory/group_vars/all/secrets.sops.yml; \
	fi

deploy: _init
	ansible-playbook site.yml

edit-secrets: _init
	@export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt; \
	sops inventory/group_vars/all/secrets.sops.yml

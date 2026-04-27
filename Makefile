.DEFAULT_GOAL := deploy
.PHONY: deploy clean edit-secrets _init check new-service lint verify-local

check:
	ansible-playbook site.yml --syntax-check

# Run every pre-commit hook against every tracked file. Use before pushing
# if you've been bypassing hooks. Slower than commit-time hooks because
# nothing is cached against the index.
lint:
	pre-commit run --all-files

# "Poor-man's CI" — what cloud CI would run, but local. Lint, syntax-check,
# and a check-mode dry run against the live host (no changes applied).
verify-local: lint check
	@echo "==> Dry-run against live host (no changes will be applied)"
	ansible-playbook site.yml --check --diff

clean:
	ansible-playbook clean.yml

# Scaffold a new service. Pass NAME and PORT (and optionally INTERNAL_PORT,
# IMAGE, USE_VPN). Example:
#   make new-service NAME=anki PORT=8765
#   make new-service NAME=jellyfin PORT=8096 IMAGE=jellyfin/jellyfin:latest
new-service:
	@scripts/new-service.sh NAME="$(NAME)" PORT="$(PORT)" \
	  $(if $(INTERNAL_PORT),INTERNAL_PORT="$(INTERNAL_PORT)") \
	  $(if $(IMAGE),IMAGE="$(IMAGE)") \
	  $(if $(USE_VPN),USE_VPN="$(USE_VPN)")

# Internal task to ensure Age key and .sops.yaml are ready
_init:
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

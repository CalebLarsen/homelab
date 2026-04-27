# Local Dependencies

To manage this homelab, your local computer needs the following tools installed.

### Core Tools
- **ansible**: The main automation engine.
- **sops**: For encrypting and decrypting secrets.
- **age**: The encryption key generator.
- **cloudflared**: For managing your Cloudflare Tunnel.

### Python Libraries (for Ansible)
- **netaddr**: Required for "Smart Subnet Discovery" in the VPN configuration.

### Lint / pre-commit (local CI — see docs/decisions/0008)
- **pre-commit**: Hook runner.
- **ansible-lint**: Ansible-specific lint.
- **yamllint**: General YAML lint.

### Ansible collections
- **community.docker**, **community.sops**, **community.general**, **ansible.posix** — pinned in `requirements.yml`. Required at runtime AND for ansible-lint's `syntax-check` rule.

---

### Quick Install (macOS)
```bash
brew install ansible sops age cloudflare/cloudflare/cloudflared
pip install netaddr pre-commit ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
pre-commit install
```

### Quick Install (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install -p ansible sops age
# Download cloudflared from https://github.com/cloudflare/cloudflared/releases
pip install netaddr pre-commit ansible-lint yamllint
ansible-galaxy collection install -r requirements.yml
pre-commit install
```

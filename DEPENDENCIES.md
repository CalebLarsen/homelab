# Local Dependencies

To manage this homelab, your local computer needs the following tools installed. 

### Core Tools
- **ansible**: The main automation engine.
- **sops**: For encrypting and decrypting secrets.
- **age**: The encryption key generator.
- **cloudflared**: For managing your Cloudflare Tunnel.

### Python Libraries (for Ansible)
- **netaddr**: Required for "Smart Subnet Discovery" in the VPN configuration.

---

### Quick Install (macOS)
```bash
brew install ansible sops age cloudflare/cloudflare/cloudflared
pip install netaddr
```

### Quick Install (Ubuntu/Debian)
```bash
sudo apt update && sudo apt install -p ansible sops age
# Download cloudflared from https://github.com/cloudflare/cloudflared/releases
pip install netaddr
```

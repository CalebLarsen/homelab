#!/usr/bin/env python3
import argparse
import os
import sys
from pathlib import Path

def main():
    parser = argparse.ArgumentParser(description="Scaffold a new homelab service.")
    parser.add_argument("name", help="Service name (lowercase, no spaces)")
    parser.add_argument("port", type=int, help="Host port to expose")
    parser.add_argument("--internal-port", type=int, help="Container's internal port (default: same as port)")
    parser.add_argument("--image", help="Container image (default: lscr.io/linuxserver/<name>:latest)")
    parser.add_argument("--use-vpn", action="store_true", help="Route through gluetun (default: False)")
    parser.add_argument("--group", default="utils", help="Service group (default: utils)")

    args = parser.parse_args()

    name = args.name.lower()
    port = args.port
    internal_port = args.internal_port or port
    image = args.image or f"lscr.io/linuxserver/{name}:latest"
    group = args.group

    repo_root = Path(__file__).parent.parent.resolve()
    service_dir = repo_root / "services" / name
    definition_file = service_dir / "definition.yml.j2"
    per_service_file = repo_root / "roles" / "service_manager" / "tasks" / "per_service" / f"{name}.yml"

    if definition_file.exists() or per_service_file.exists():
        print(f"Error: Service '{name}' already exists.", file=sys.stderr)
        sys.exit(1)

    service_dir.mkdir(parents=True, exist_ok=True)
    per_service_file.parent.mkdir(parents=True, exist_ok=True)

    definition_content = f"""{{% from "service_base.yml.j2" import standard_service with context %}}
{{{{ standard_service(
    name="{name}",
    internal_port={internal_port}
) }}}}
"""
    definition_file.write_text(definition_content)

    per_service_content = f"""---
# Per-service pre-deploy configuration for {name}.
# Add tasks here only if {name} needs config templating, directory setup,
# or other steps beyond the standard compose deploy.
"""
    per_service_file.write_text(per_service_content)

    use_vpn_line = "\n    use_vpn: true" if args.use_vpn else ""

    print(f"✓ Created {definition_file.relative_to(repo_root)}")
    print(f"✓ Created {per_service_file.relative_to(repo_root)}")
    print(f"\nNow add this snippet under  services:  in inventory/group_vars/all/main.yml:\n")
    print(f"  - name: {name}")
    print(f"    group: {group}")
    print(f"    port: {port}{use_vpn_line}")
    print(f"    image: \"{image}\"")
    print(f"\nThen run:  make deploy")

if __name__ == "__main__":
    main()

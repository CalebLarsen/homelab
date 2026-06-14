# Homelab Project Instructions

## Infrastructure & Tooling
- **Remote Docker Only**: Docker is NOT installed or available on the local machine (the environment where this CLI runs). All Docker operations are performed on remote hosts via Ansible (e.g., using `community.docker` modules).
- **No Local Validation**: Do not attempt to run `docker` commands or validate compose files using a local Docker daemon. Use Ansible's `check_mode` or remote execution for verification.

## Testing & Validation
- **Molecule**: Isolated role testing is configured using Molecule with the Docker driver.
  - **Prerequisites**: Requires local Docker and `molecule` installed via pip.
  - **Usage**: Navigate to a role (e.g., `roles/host_cron`) and run `molecule test`.
  - **Coverage**: Initial Molecule support is implemented for `pre_flight` and `host_cron`.

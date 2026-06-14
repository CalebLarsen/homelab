# Homelab Project Instructions

## Infrastructure & Tooling
- **Remote Docker Only**: Docker is NOT installed or available on the local machine (the environment where this CLI runs). All Docker operations are performed on remote hosts via Ansible (e.g., using `community.docker` modules).
- **No Local Validation**: Do not attempt to run `docker` commands or validate compose files using a local Docker daemon. Use Ansible's `check_mode` or remote execution for verification.

## Testing & Validation
- **Molecule**: Isolated role testing is configured using Molecule with the Docker driver.
  - **Remote Testing**: To align with the "Remote Docker Only" mandate, Molecule can be configured to use the homelab host as its Docker backend.
  - **Usage**:
    ```bash
    # Use the Makefile (recommended)
    make test-role ROLE=host_cron

    # OR manual: Set DOCKER_HOST to point to the remote homelab
    export DOCKER_HOST="ssh://caleb@$(grep ansible_host inventory/hosts.yml | awk '{print $2}')"
    cd roles/host_cron && molecule test
    ```
  - **Coverage**: Initial Molecule support is implemented for `pre_flight` and `host_cron`.

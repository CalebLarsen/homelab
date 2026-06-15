# Homelab Architectural Refactor TODO

This document tracks the technical debt and architectural "smells" identified during the senior-level review on 2026-06-14. These items are prioritized to improve maintainability, reduce cognitive load, and increase system reliability.

## 1. Decompose the `service_manager` "God Role"
The `service_manager` role is overloaded with unrelated responsibilities.
- [x] Split directory management into a `base_directories` or `filesystem` role.
- [x] Move CI infrastructure (mocks, seeding scripts) into a `ci_infrastructure` role.
- [x] Separate app-specific API provisioning from the core Docker orchestration.
- [x] Create a specialized `docker_orchestrator` role focused solely on stack deployment.

## 2. Unify Fragmented Service Logic
Service logic is currently scattered across `inventory`, `services/`, and multiple task files.
- [x] Define a standard "Service Schema" to encapsulate all properties (ports, images, VPN, API settings) in one place. (`services/*/service.yml`)
- [x] Reduce the "treasure hunt" required to add or modify a service. (Logic co-located in `services/*/tasks/`)
- [x] Investigate using a single source of truth for both Compose snippets and API wiring metadata. (Dynamic loader in `pre_flight`)

## 3. Replace Imperative Scripting with Declarative Plugins
The codebase uses "Ansible as a scripting engine" for complex logic.
- [x] **Custom Filter:** Replace the inline Python PBKDF2 hash calculation in `qbittorrent.yml` with a proper Ansible filter plugin.
- [x] **State Management:** Find a more declarative way to manage Cleanuparr state instead of raw SQL injection. (Moved to templates, improved maintainability).
- [x] **Proper Handlers:** Refactor the manual `docker stop` calls into a more robust service management pattern. (Used `docker_container` module).

## 4. Refactor Brittle API Orchestration (`api_wiring.yml`)
The current API provisioning relies on manual `uri` calls and complex Jinja2 loops.
- [x] Abstract the API wiring logic into custom Ansible modules or specialized scripts. (Decomposed into per-service `wiring.yml` tasks).
- [ ] Decouple wiring from `localhost` and fixed ports where possible.
- [ ] Simplify the cross-app tagging logic (Seerr/Sonarr/Radarr) into a more maintainable structure.

## 5. Isolate CI and Production Concerns
Production deployment code is cluttered with CI-specific tasks.
- [x] Strictly separate CI mock logic from production playbooks.
- [x] Use Ansible tags or separate playbooks to ensure CI tools (like `ci-mock` and `seed-servarr`) are never deployed to production by accident.

## 6. Close the Testing Gap
The core of the homelab (orchestration and API wiring) has automated coverage.
- [x] Implement Molecule tests for the `filesystem` role.
- [ ] Implement Molecule tests for the `docker_orchestrator` role.
- [x] Create integration tests that verify API wiring between services. (Refined existing tests for robustness).
- [ ] Prioritize testing for high-logic roles like `prowlarr_indexers` and `seerr_provisioning`.
- [x] **YAML & Template Validation:**
  - [x] Expand `ansible-lint` coverage to include `services/*/tasks/*.yml`.
  - [x] Implement a validation script (e.g., in `scripts/validate-templates.py`) that renders Docker Compose templates and checks for syntax errors.
  - [x] Ensure all `service.yml` files are caught by `yamllint` and `ansible-lint` where appropriate.
  - [x] Add a `make verify-templates` target to the Makefile for local validation.
  - [x] Create a unified `make test` entrypoint for the full suite (lint, syntax, templates, molecule).

## 7. Clean Up Technical Debt & Naming Smells
Address half-finished migrations and misleading identifiers.
- [x] **Rename:** Complete the Overseerr -> Seerr rename across all files, variables, and tasks to match the ADR.
- [x] **Audit:** Remove or resolve "Legacy cleanup" markers and half-implemented logic.
- [x] **Standardize:** Ensure consistent naming conventions for variables (e.g., `homelab_...` vs global variables).

# 0003 — Reclaim container names from unmanaged containers before deploy

## Context

Docker container names are globally unique on the host. Compose refuses to
create a container when the name is already taken, even if the existing
container belongs to a different (or no) compose project. In a homelab
that gets manual `docker run` experiments, aborted deploys, and
pre-Ansible legacy containers, this collision is common.

See `roles/service_manager/tasks/main.yml` — the steps using
`community.docker.docker_container_info` to find collisions and
`community.docker.docker_container` with `state: absent` to remove the
ones not labeled by compose.

## Decision

Before each compose deploy, the service_manager role:

1. Looks up any container holding the name of a service in the inventory.
2. Checks the container's labels for `com.docker.compose.project`.
3. If the label is missing or does not match the service name, the
   container is removed (`state: absent`) so compose can recreate it
   under proper management.

A container that already has the matching `com.docker.compose.project`
label is left alone (compose will reconcile it on the deploy step).

## Why

Without this step, the playbook fails on the first re-deploy after any
manual `docker run`, leaving the operator to figure out which name is
taken and remove it by hand. The label check ensures we only remove
unmanaged containers — never a healthy compose-managed one we are about
to redeploy.

## What breaks if you undo this

`community.docker.docker_compose_v2` calls fail with "container name
already in use" the first time someone runs an image manually or the
first time the playbook is run against a host with pre-existing
containers. The deploy stops mid-flight, leaving the host in a partial
state.

**Do not delete this step** unless every host this playbook touches is
known to be a clean install, with no manual containers ever.

# Plex Guest Isolation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement a fully automated isolation system where guests only see their own requests in Plex via a "Label" system.

**Architecture:** We use Seerr to auto-tag requests in Sonarr/Radarr. Kometa then reads these tags and applies corresponding Labels to the items in Plex. Plex's built-in "Sharing" restrictions then filter the library for the guest based on these labels.

**Tech Stack:** Ansible, Seerr (Overseerr), Sonarr, Radarr, Kometa, Plex.

---

### Task 1: Update User Secrets Schema

**Files:**
- Modify: `inventory/group_vars/all/secrets.sops.yml` (via `make edit-secrets`)

- [ ] **Step 1: Identify existing users**
Review the current user list in your secrets to identify who needs labels.

- [ ] **Step 2: Add label field to user entries**
For each guest user, add a `label` field. This string will be used as both the Sonarr/Radarr tag and the Plex Label.

```yaml
seerr_secret:
  users:
    - { email: "admin@example.com", permissions: 2 }
    - { email: "guest@example.com", permissions: 32, label: "guest-name" }
```

- [ ] **Step 3: Save and Verify Encryption**
Save the file and ensure SOPS re-encrypts it successfully.

### Task 2: Configure Seerr Auto-Tagging

**Files:**
- Modify: `roles/service_manager/tasks/api_wiring.yml`

- [ ] **Step 1: Enable tagRequests for Radarr and Sonarr**
Update the API provisioning to ensure Seerr's "Tag Requests" setting is enabled for both services.

```yaml
- name: Enable Overseerr Auto-Tagging (Radarr/Sonarr)
  ansible.builtin.uri:
    url: "http://localhost:5055/api/v1/settings/{{ item }}/0"
    method: PUT
    headers: { X-Api-Key: "{{ seerr_secret.api_key }}" }
    body_format: json
    body: { tagRequests: true }
    status_code: [200, 201, 400]
  loop: ["radarr", "sonarr"]
```
*(Note: This logic may already exist in your wiring, verify and ensure it is correct.)*

- [ ] **Step 2: Run deploy to apply Seerr settings**
Run `make deploy` to push the configuration to your Seerr instance.

### Task 3: Configure Dynamic Kometa Labels

**Files:**
- Modify: `roles/service_manager/templates/kometa_config.yml.j2`

- [ ] **Step 1: Implement dynamic label operations**
Update the Kometa configuration template to iterate over all users in `seerr_secret.users` who have a `label` defined.

```yaml
libraries:
  Movies:
    remove_overlays: false
    operations:
      label:
{% for user in seerr_secret.users if user.label is defined %}
        - name: {{ user.label }}
          radarr_tag: {{ user.label }}
{% endfor %}
  TV Shows:
    remove_overlays: false
    operations:
      label:
{% for user in seerr_secret.users if user.label is defined %}
        - name: {{ user.label }}
          sonarr_tag: {{ user.label }}
{% endfor %}
```

- [ ] **Step 2: Ensure sync_mode is append**
Verify that `settings.sync_mode` is set to `append` in the same file to prevent users from wiping out each other's labels.

```yaml
settings:
  sync_mode: append
```

- [ ] **Step 3: Run deploy**
Run `make deploy` to update the Kometa configuration.

### Task 4: Manual Plex Setup & Validation

**Files:**
- Documentation: `docs/PLEX_USER_ONBOARDING.md`

- [ ] **Step 1: Restrict Guest in Plex UI**
Perform the one-time manual restriction for the guest:
1. Plex -> Settings -> Manage Library Access -> [Guest User].
2. Restrictions -> Labels.
3. Add the label defined in Task 1 (e.g., `guest-name`).
4. Save.

- [ ] **Step 2: Perform a test request**
Log into Seerr as the guest and request a movie.

- [ ] **Step 3: Verify Tag in Radarr**
Check Radarr to ensure the item has the correct tag.

- [ ] **Step 4: Run Kometa and Verify Label**
Trigger a Kometa run and verify the label is applied in Plex.

- [ ] **Step 5: Confirm Visibility**
Check the guest's Plex view to ensure only their request is visible.

- [ ] **Step 6: Update Onboarding Documentation**
Update `docs/PLEX_USER_ONBOARDING.md` to include these new steps for future guests.

# Onboarding a User to Plex

End-to-end flow for granting someone access to your Plex server and the
Overseerr request portal that fronts it.

## Prerequisites

- The new user already has a free Plex account at <https://plex.tv>.
- You have admin access to your own Plex server and to this repo's secrets
  (`make edit-secrets`).

## Step 1 — Share libraries from Plex

Plex itself owns the access control for streaming. This step is manual via
Plex's web UI.

1. Sign in at <https://app.plex.tv> as the server owner.
2. Settings → **Manage Library Access** (or **Friends** in older UIs) →
   **Add Friend**.
3. Enter the new user's email address (must match the email on their Plex
   account).
4. Select which libraries to share. Typically:
   - Movies
   - TV Shows
   - Audiobooks (if you've also added them to Audiobookshelf separately)
5. Set their per-library permissions (allow downloads, restrict to certain
   labels, etc.) and click **Send Invite**.
6. Plex emails the user; they must accept before they can stream anything.

You can verify the share landed by visiting
**Settings → Users & Sharing**; the user should show as `Pending` until
they accept and `Accepted` thereafter.

## Step 2 — Add the user to Overseerr (the request portal)

Overseerr is wired up to your Plex server in this repo, but it doesn't
automatically grant request permissions to every Plex friend. You add them
via the SOPS-encrypted secrets file so the playbook can provision them on
the next deploy.

```bash
make edit-secrets
```

In the editor, append the new entry under `overseerr_secret.users`:

```yaml
overseerr_secret:
  users:
    - { email: "you@example.com", permissions: 2 }            # admin (you)
    - { email: "newuser@example.com", permissions: 32 }       # standard requester
    - { email: "powerfan@example.com", permissions: 32, label: "power-fan" }
```

### Permissions cheat sheet

Overseerr stores permissions as a bitmask. Common single-permission values:

| Value | Meaning                               |
|-------|---------------------------------------|
| 2     | **Admin** — full control              |
| 16    | **Request** movies                    |
| 32    | **Request** TV shows                  |
| 4096  | **Auto-approve** their requests       |
| 8192  | **Auto-approve** 4K (if 4K is enabled)|

Combine with bitwise OR. e.g. `48` = request movies + TV shows. `2` alone
covers everything because admins implicitly have all bits.

The `label` field (optional) is only consumed by Kometa to tag content
that user requested — useful if you want per-user collections in Plex.

Save and exit; SOPS re-encrypts on close.

## Step 3 — Apply

```bash
make deploy
```

The playbook will:

1. Trigger Overseerr's "import Plex friends" sync (it pulls everyone you
   shared with in Step 1).
2. Look up each entry in `overseerr_secret.users` by email and apply the
   permissions you configured.

If the user doesn't appear in Overseerr after a successful deploy, the most
common cause is that they haven't *accepted* the Plex invite yet — Overseerr
only imports accepted friends.

## Step 4 — Hand off the URL

Send the user the Overseerr request URL (typically
`https://request.<your-domain>`) and tell them to log in with **"Sign in
with Plex"**. Their permissions are already set; no further config needed.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| User missing from Overseerr after deploy | Plex invite not yet accepted, or email in `overseerr_secret.users` doesn't exactly match their Plex account email |
| "No requests permission" in Overseerr UI | `permissions:` value is too restrictive; bump to `48` (movies + TV) or `2` (admin) |
| User can request but content never imports | Sonarr/Radarr root folders or quality profile not set — check the deploy verify output |
| Kometa labels not applied | `label:` missing from the user entry, or Kometa hasn't run since you added it (it's a once-per-deploy run) |

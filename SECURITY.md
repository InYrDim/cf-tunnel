# Security Policy

## Reporting a vulnerability

If you find a security issue in this repository's configuration (not in
Cloudflare's or Docker's own products), please open a private report via
GitHub's "Report a vulnerability" button under the Security tab instead of
a public issue, so it can be fixed before details are public.

## Secrets

This project only ever needs one secret: `CLOUDFLARE_TUNNEL_TOKEN`, stored
locally in a git-ignored `.env` file.

- Never commit `.env`. Only `.env.example` (with a placeholder value)
  belongs in the repo.
- If a real token ever ends up in git history, a commit, a screenshot, or
  a chat log, treat it as compromised: revoke/rotate it immediately in the
  Cloudflare Zero Trust dashboard (**Networks → Tunnels → your tunnel →
  Refresh token / delete + recreate the connector**), don't just delete
  the file. Deleting a file does not remove it from git history.
- This repo ships a Gitleaks GitHub Action (`.github/workflows/gitleaks.yml`)
  that scans every push and pull request for accidentally committed
  secrets. Keep it enabled.

## Runtime hardening already applied

- Container images are pinned to specific versions, not `:latest`.
- Both containers run with `cap_drop: [ALL]`, `no-new-privileges`, and a
  read-only root filesystem (writable paths are explicit `tmpfs` mounts).
- The `web` backend is not published to the host — it's reachable only
  from the `tunnel` container over the internal Docker network, so
  inbound traffic can only arrive through Cloudflare.
- Container logs are size- and count-limited to avoid unbounded disk use.

# cf-tunnel

Docker Compose setup for a [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/)
with an Nginx backend, hardened for running as a **public** repository.

## ⚠️ If you got this repo from a template/zip with a real token in `.env`

Delete the value, then **revoke/rotate that token immediately** in the
Cloudflare Zero Trust dashboard (Networks → Tunnels → your tunnel →
recreate the connector). A token that has ever touched a file, a zip, a
screenshot, or a chat is compromised — deleting the file is not enough.
See [SECURITY.md](./SECURITY.md).

## Architecture

```
Internet → Cloudflare edge → [tunnel] (cloudflared, outbound-only) → [web] (nginx:8080)
```

- **`tunnel`** — the cloudflared connector. It makes an *outbound* connection
  to Cloudflare; no inbound ports are opened on your host or router.
- **`web`** — a minimal Nginx backend. It is **not** published to the host
  (no `ports:` mapping) — it's only reachable from `tunnel` over Docker's
  internal network, so the only way in from the internet is through
  Cloudflare. Replace it with your own app, or point the tunnel's public
  hostname (configured in the Zero Trust dashboard) at any other container
  on the shared `cloudflare-bridge` network instead.

## Prerequisites

- Docker Engine + the `docker compose` v2 plugin (`docker compose version`
  should work; the legacy Python `docker-compose` v1 binary is not
  supported by this file).
- A Cloudflare account with a Tunnel already created in the
  [Zero Trust dashboard](https://one.dash.cloudflare.com/) → Networks →
  Tunnels, so you have a connector token to use below.

## Setup

### Quick setup (automated)

```bash
./setup.sh
```

This creates the external `cloudflare-bridge` network, copies
`.env.example` to `.env` if needed, checks that a real token is set (not
the placeholder), warns you if `.env` is ever accidentally tracked by
git, and starts the stack.

### Manual setup

```bash
docker network create cloudflare-bridge   # if it doesn't already exist
cp .env.example .env
chmod 600 .env
# edit .env and set CLOUDFLARE_TUNNEL_TOKEN
docker compose up -d
```

## Configuration

| Variable                  | Description                                                      |
|----------------------------|-------------------------------------------------------------------|
| `CLOUDFLARE_TUNNEL_TOKEN` | Connector token from the Zero Trust dashboard. **Not** the same thing as a Cloudflare API Token. |

`web` listens on container port `8080` internally (see
`nginx/conf.d/default.conf`); it is intentionally never exposed to the
host.

## Security

- **Never commit `.env`.** Only `.env.example` (a placeholder) belongs in
  the repo — `.gitignore` already excludes `.env`.
- **Rotate on exposure.** If a real token is ever committed, pasted
  somewhere public, or otherwise leaked, revoke and reissue it in the
  dashboard rather than assuming a `git rm` fixes it — git history keeps
  old commits around, and a rewrite of history is best-effort at cleaning
  up something that may already be cached/forked elsewhere.
- **Automated secret scanning.** `.github/workflows/gitleaks.yml` scans
  every push/PR (and daily) for accidentally committed secrets — keep it
  enabled, and treat any alert as urgent.
- **Least privilege in Cloudflare, not just Docker.** Put your public
  hostnames behind [Cloudflare Access](https://developers.cloudflare.com/cloudflare-one/policies/access/)
  policies where the content isn't meant to be fully public, and scope
  Tunnel ingress rules to only the hostnames/services you actually need.
- **Pinned image versions.** `cloudflared` and `nginx` are pinned to
  specific versions rather than `:latest`, so deployments are
  reproducible and you control exactly when you take an update. Consider
  [Renovate](https://docs.renovatebot.com/) or
  [Dependabot](https://docs.github.com/en/code-security/dependabot) to
  open PRs bumping them automatically.
- **Container hardening applied to both services:**
  - `cap_drop: [ALL]` (with only the couple of capabilities `nginx` needs
    to drop root privileges added back explicitly)
  - `security_opt: [no-new-privileges:true]`
  - `read_only: true` root filesystem, with explicit `tmpfs` mounts for
    the few paths that must be writable at runtime
  - Log rotation (`max-size`/`max-file`) so container logs can't fill
    the disk
  - CPU/memory limits per container
- **File permissions.** `setup.sh` sets `.env` to `600` (owner
  read/write only).

## Updating image versions

```bash
# check the latest tags, then edit docker-compose.yml:
# https://github.com/cloudflare/cloudflared/releases
# https://hub.docker.com/_/nginx/tags
docker compose pull
docker compose up -d
```

## Commands

```bash
docker compose logs -f      # view logs
docker compose ps           # check health status
docker compose down         # stop and remove containers
docker compose restart      # restart services

# Inspect connected container to cloudflare-bridge network
docker network inspect cloudflare-bridge --format '{{json .Containers}}' | jq 
```

## License

No license file is included yet — add a `LICENSE` (e.g. MIT, Apache-2.0)
before treating this as open source; without one, default copyright
applies and others technically can't reuse the code even in a public repo.



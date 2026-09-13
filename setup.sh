#!/bin/bash
# Sets up and starts the Cloudflare Tunnel stack.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"

echo "==> Setting up Cloudflare Tunnel..."

# --- Pre-flight: required tools ---------------------------------------------
if ! command -v docker >/dev/null 2>&1; then
    echo "ERROR: docker is not installed or not on PATH." >&2
    exit 1
fi
if ! docker compose version >/dev/null 2>&1; then
    echo "ERROR: the 'docker compose' plugin (Compose v2) is required." >&2
    echo "       (legacy 'docker-compose' v1 is not supported by this file)" >&2
    exit 1
fi

# --- External network --------------------------------------------------------
if ! docker network inspect cloudflare-bridge >/dev/null 2>&1; then
    echo "==> Creating cloudflare-bridge network..."
    docker network create cloudflare-bridge
fi

# --- .env setup ---------------------------------------------------------------
if [ ! -f .env ]; then
    echo "==> Creating .env from .env.example..."
    cp .env.example .env
    chmod 600 .env
    echo ""
    echo "!! Edit .env now and set CLOUDFLARE_TUNNEL_TOKEN, then re-run this script."
    exit 0
fi
chmod 600 .env

# --- Safety net: fail fast on placeholder / empty token ---------------------
# shellcheck disable=SC1091
source .env
if [ -z "${CLOUDFLARE_TUNNEL_TOKEN:-}" ] || [ "${CLOUDFLARE_TUNNEL_TOKEN}" = "your_cloudflare_tunnel_token_here" ]; then
    echo "ERROR: CLOUDFLARE_TUNNEL_TOKEN in .env is missing or still the placeholder value." >&2
    echo "       Get a real token from the Zero Trust dashboard and set it in .env." >&2
    exit 1
fi

# --- Safety net: warn (loudly) if .env is ever tracked by git ---------------
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git ls-files --error-unmatch .env >/dev/null 2>&1; then
        echo ""
        echo "###############################################################"
        echo "# WARNING: .env is TRACKED BY GIT. Your tunnel token is at    #"
        echo "# risk of being pushed to a remote (public or private).       #"
        echo "# Run:  git rm --cached .env                                  #"
        echo "# and rotate the token in the Cloudflare Zero Trust dashboard #"
        echo "# if it was ever pushed.                                      #"
        echo "###############################################################"
        echo ""
    fi
fi

echo "==> Starting services..."
docker compose up -d

echo "==> Done. Run 'docker compose logs -f' to monitor startup."

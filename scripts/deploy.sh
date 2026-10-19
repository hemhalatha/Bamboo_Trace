#!/bin/bash
# ============================================================
# BambooTrace — Deploy / Redeploy Script
# Run on the Azure VM from any directory
# Usage: bash scripts/deploy.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"
COMPOSE_FILE="$REPO_DIR/docker-compose.azure.yml"
NGINX_CONF="/etc/nginx/sites-available/bambootrace"

echo "================================================"
echo " BambooTrace Deploy"
echo "================================================"

# --- Validate .env exists ---
if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found!"
    echo "Run: cp .env.azure.example .env && nano .env"
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: Azure Compose file not found: $COMPOSE_FILE"
    exit 1
fi

compose() {
    docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" "$@"
}

# --- Pull latest code ---
echo "[1/5] Pulling latest code from GitHub..."
git -C "$REPO_DIR" pull --ff-only origin main

# --- Copy Nginx config ---
echo "[2/5] Installing Nginx config..."
sudo cp "$REPO_DIR/nginx.azure.conf" "$NGINX_CONF"
sudo ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/bambootrace
# Disable default site if it exists
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
echo "       Nginx configured OK"

# --- Build and start Docker Compose ---
echo "[3/5] Building and starting containers..."
compose config --quiet
compose up -d --build

# --- Wait for containers to be healthy ---
echo "[4/5] Waiting for services to be healthy (up to 90s)..."
HEALTHY=no
for i in $(seq 1 18); do
    HEALTHY=$(compose ps --format json 2>/dev/null | python3 -c '
import json
import sys

raw = sys.stdin.read().strip()
try:
    parsed = json.loads(raw)
    containers = parsed if isinstance(parsed, list) else [parsed]
except json.JSONDecodeError:
    containers = [json.loads(line) for line in raw.splitlines() if line.strip()]

services = {container.get("Service"): container for container in containers}
expected = ("backend", "frontend")
healthy = all(
    service in services
    and services[service].get("State") == "running"
    and services[service].get("Health") == "healthy"
    for service in expected
)
print("yes" if healthy else "no")
' 2>/dev/null || echo "no")

    if [ "$HEALTHY" = "yes" ]; then
        echo "       All containers healthy!"
        break
    fi
    echo "       Waiting... ($((i*5))s)"
    sleep 5
done

if [ "$HEALTHY" != "yes" ]; then
    echo "ERROR: Containers did not become healthy within 90 seconds."
    echo "Check logs: docker compose -f $COMPOSE_FILE logs --tail=50"
    exit 1
fi

# --- Smoke test ---
echo "[5/5] Running smoke test..."
if curl --fail --silent --show-error http://127.0.0.1/api/health >/dev/null; then
    echo "       Application health check PASSED"
else
    echo "ERROR: Application health check failed."
    echo "Check logs: docker compose -f $COMPOSE_FILE logs --tail=50"
    exit 1
fi

echo ""
echo "================================================"
echo " Deploy complete!"
echo "================================================"
echo ""
echo " The app is running behind Nginx on this Azure VM."
echo " Configure DNS and HTTPS termination in front of this VM before production use."
echo ""
echo " Useful commands:"
echo "   docker compose -f $COMPOSE_FILE ps"
echo "   docker compose -f $COMPOSE_FILE logs -f"
echo "   docker compose -f $COMPOSE_FILE logs -f backend"
echo ""

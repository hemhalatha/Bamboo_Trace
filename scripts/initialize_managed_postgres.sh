#!/bin/bash
# ============================================================
# Initialize the BambooTrace schema in managed PostgreSQL.
# Use for a new database or after reviewing a schema change.
# Usage: bash scripts/initialize_managed_postgres.sh
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_DIR/.env"
COMPOSE_FILE="$REPO_DIR/docker-compose.azure.yml"

if [ ! -f "$ENV_FILE" ]; then
    echo "ERROR: .env file not found. Copy and configure .env.azure.example first."
    exit 1
fi

if [ ! -f "$COMPOSE_FILE" ]; then
    echo "ERROR: Azure Compose file not found: $COMPOSE_FILE"
    exit 1
fi

docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" config --quiet

echo "Initializing the managed PostgreSQL schema..."
docker compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" \
    run --build --rm --no-deps backend python -c '
import app.main
from app.core.database import (
    Base,
    engine,
    ensure_batch_columns,
    ensure_custom_order_request_columns,
    ensure_order_columns,
    ensure_project_columns,
    ensure_user_columns,
)

Base.metadata.create_all(bind=engine)
ensure_user_columns()
ensure_order_columns()
ensure_project_columns()
ensure_batch_columns()
ensure_custom_order_request_columns()
'

echo "Managed PostgreSQL schema initialization completed."

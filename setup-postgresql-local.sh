#!/bin/bash
# Setup PostgreSQL databases for Apache Fineract local development
# Usage: ./setup-postgresql-local.sh
#
# This script creates the required databases and grants permissions.
# Run this once before starting Fineract for the first time.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables
if [ -f "$SCRIPT_DIR/.env.postgresql" ]; then
    set -a
    source "$SCRIPT_DIR/.env.postgresql"
    set +a
fi

DB_USER="${FINERACT_HIKARI_USERNAME:-postgres}"
DB_HOST="${FINERACT_DEFAULT_TENANTDB_HOSTNAME:-localhost}"
DB_PORT="${FINERACT_DEFAULT_TENANTDB_PORT:-5432}"
TENANTS_DB="${FINERACT_DEFAULT_TENANTDB_NAME:-fineract_default}"
TENANTS_STORE_DB="fineract_tenants"

echo "Setting up PostgreSQL for Apache Fineract..."
echo "  Host: $DB_HOST:$DB_PORT"
echo "  User: $DB_USER"

# Detect psql path (Windows compatibility)
if command -v psql &> /dev/null; then
    PSQL_CMD="psql"
elif [ -f "/c/Program Files/PostgreSQL/16/bin/psql" ]; then
    PSQL_CMD="/c/Program Files/PostgreSQL/16/bin/psql"
elif [ -f "/c/Program Files/PostgreSQL/15/bin/psql" ]; then
    PSQL_CMD="/c/Program Files/PostgreSQL/15/bin/psql"
else
    echo "ERROR: psql not found. Please install PostgreSQL or add it to PATH."
    exit 1
fi

export PGPASSWORD="${FINERACT_HIKARI_PASSWORD:-postgres}"

# Create databases if they don't exist
for DB_NAME in "$TENANTS_STORE_DB" "$TENANTS_DB"; do
    if "$PSQL_CMD" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
        echo "  Database '$DB_NAME' already exists."
    else
        echo "  Creating database '$DB_NAME'..."
        "$PSQL_CMD" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -c "CREATE DATABASE $DB_NAME;"
    fi
done

# Grant permissions
for DB_NAME in "$TENANTS_STORE_DB" "$TENANTS_DB"; do
    "$PSQL_CMD" -U "$DB_USER" -h "$DB_HOST" -p "$DB_PORT" -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO $DB_USER;" 2>/dev/null || true
done

echo ""
echo "PostgreSQL setup complete!"
echo "Run './run-postgresql-local.sh' to start Fineract."

#!/bin/bash
# Run Apache Fineract locally with PostgreSQL
# Usage: ./run-postgresql-local.sh
#
# Prerequisites:
#   1. PostgreSQL running on localhost:5432
#   2. Java 21+ installed
#   3. Databases created (see setup-postgresql-local.sh)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load environment variables from .env.postgresql
if [ -f "$SCRIPT_DIR/.env.postgresql" ]; then
    echo "Loading configuration from .env.postgresql..."
    set -a
    source "$SCRIPT_DIR/.env.postgresql"
    set +a
else
    echo "ERROR: .env.postgresql not found. Copy .env.postgresql.example and configure it."
    exit 1
fi

echo "Starting Apache Fineract with PostgreSQL..."
echo "  Database URL: $FINERACT_HIKARI_JDBC_URL"
echo "  Tenant DB:    $FINERACT_DEFAULT_TENANTDB_NAME"

cd "$SCRIPT_DIR"
./gradlew :fineract-provider:bootRun --no-daemon

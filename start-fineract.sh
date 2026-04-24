#!/bin/bash
# =============================================================================
# Apache Fineract — Local HTTPS Startup Script
# =============================================================================
# Prerequisites:
#   - Java 21+       (OpenJDK / Temurin)
#   - PostgreSQL 16  (localhost:5432, user: postgres, password: postgres)
#   - Databases:     fineract_tenants, fineract_default
#
# Usage:
#   bash start-fineract.sh              # start everything
#   bash start-fineract.sh --setup-db   # create DBs first, then start
#   bash start-fineract.sh --check      # check status only
#
# Access after startup:
#   HTTPS API : https://localhost:8443/fineract-provider/api/v1/
#   Login     : mifos / password
#   Tenant    : Fineract-Platform-TenantId: default
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="/tmp/fineract-startup.log"
PSQL="/c/Program Files/PostgreSQL/16/bin/psql.exe"
PG_CTL="/c/Program Files/PostgreSQL/16/bin/pg_ctl.exe"
PG_ISREADY="/c/Program Files/PostgreSQL/16/bin/pg_isready.exe"
PG_DATA="/c/Program Files/PostgreSQL/16/data"
PGPASSWORD="postgres"
PG_USER="postgres"
PG_HOST="localhost"
PG_PORT="5432"
FINERACT_URL="https://localhost:8443/fineract-provider/api/v1/offices"
FINERACT_AUTH="Basic bWlmb3M6cGFzc3dvcmQ="  # mifos:password base64

export PGPASSWORD

# -----------------------------------------------------------------------------
# STEP 0: Parse args
# -----------------------------------------------------------------------------
SETUP_DB=false
CHECK_ONLY=false
for arg in "$@"; do
  case $arg in
    --setup-db) SETUP_DB=true ;;
    --check)    CHECK_ONLY=true ;;
  esac
done

# -----------------------------------------------------------------------------
# STEP 1: Check Java
# -----------------------------------------------------------------------------
echo ""
echo "=========================================="
echo " Apache Fineract — Local HTTPS Startup"
echo "=========================================="
echo ""
echo "[1/4] Checking Java..."
if ! java -version 2>&1 | grep -q "version"; then
  echo "ERROR: Java not found. Install Java 21+ and add to PATH."
  exit 1
fi
JAVA_VER=$(java -version 2>&1 | head -1)
echo "      OK — $JAVA_VER"

# -----------------------------------------------------------------------------
# STEP 2: Start PostgreSQL if not running
# -----------------------------------------------------------------------------
echo ""
echo "[2/4] Checking PostgreSQL..."
if "$PG_ISREADY" -h "$PG_HOST" -p "$PG_PORT" > /dev/null 2>&1; then
  echo "      OK — PostgreSQL already running on $PG_HOST:$PG_PORT"
else
  echo "      PostgreSQL not running. Starting..."
  "$PG_CTL" start -D "$PG_DATA" > /dev/null 2>&1 || true
  sleep 4
  if "$PG_ISREADY" -h "$PG_HOST" -p "$PG_PORT" > /dev/null 2>&1; then
    echo "      OK — PostgreSQL started on $PG_HOST:$PG_PORT"
  else
    echo "ERROR: Could not start PostgreSQL. Check if service is installed."
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# STEP 3: Setup databases (if --setup-db flag or first run)
# -----------------------------------------------------------------------------
if [ "$SETUP_DB" = true ]; then
  echo ""
  echo "[3/4] Setting up Fineract databases..."
  for DB in fineract_tenants fineract_default; do
    EXISTS=$("$PSQL" -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" -lqt 2>/dev/null | cut -d\| -f1 | grep -w "$DB" | wc -l)
    if [ "$EXISTS" -gt 0 ]; then
      echo "      DB '$DB' already exists — skipping"
    else
      echo "      Creating database '$DB'..."
      "$PSQL" -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" -c "CREATE DATABASE $DB;" > /dev/null 2>&1
    fi
    "$PSQL" -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" -d "$DB" \
      -c "GRANT ALL ON SCHEMA public TO $PG_USER;" > /dev/null 2>&1 || true
  done
  echo "      OK — Databases ready"
else
  echo ""
  echo "[3/4] Verifying Fineract databases..."
  for DB in fineract_tenants fineract_default; do
    EXISTS=$("$PSQL" -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" -lqt 2>/dev/null | cut -d\| -f1 | grep -w "$DB" | wc -l)
    if [ "$EXISTS" -eq 0 ]; then
      echo "ERROR: Database '$DB' not found. Run: bash start-fineract.sh --setup-db"
      exit 1
    fi
  done
  echo "      OK — fineract_tenants and fineract_default present"
fi

# -----------------------------------------------------------------------------
# STATUS CHECK ONLY
# -----------------------------------------------------------------------------
if [ "$CHECK_ONLY" = true ]; then
  echo ""
  echo "[4/4] Checking Fineract API..."
  HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$FINERACT_URL" \
    -H "Fineract-Platform-TenantId: default" \
    -H "Authorization: $FINERACT_AUTH" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    echo "      OK — Fineract is RUNNING at https://localhost:8443"
  else
    echo "      Fineract is NOT running (HTTP $HTTP_CODE)"
  fi
  echo ""
  exit 0
fi

# -----------------------------------------------------------------------------
# STEP 4: Check if Fineract already running
# -----------------------------------------------------------------------------
echo ""
echo "[4/4] Starting Apache Fineract (HTTPS on port 8443)..."
HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$FINERACT_URL" \
  -H "Fineract-Platform-TenantId: default" \
  -H "Authorization: $FINERACT_AUTH" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  echo "      Fineract is already running at https://localhost:8443"
  echo ""
  echo "=========================================="
  echo " Status: ALREADY RUNNING"
  echo " API   : https://localhost:8443/fineract-provider/api/v1/"
  echo " Login : mifos / password"
  echo " Tenant: default"
  echo "=========================================="
  exit 0
fi

echo "      Clearing Liquibase locks (prevents stuck-lock failures)..."
for DB in fineract_tenants fineract_default; do
  "$PSQL" -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" -d "$DB" \
    -c "UPDATE public.databasechangeloglock SET LOCKED = FALSE, LOCKGRANTED = NULL, LOCKEDBY = NULL WHERE ID = 1;" \
    > /dev/null 2>&1 || true
done
echo "      OK — Locks cleared"
echo "      Launching Fineract — log: $LOG_FILE"
cd "$SCRIPT_DIR"
bash run-postgresql-local.sh > "$LOG_FILE" 2>&1 &
FINERACT_BG_PID=$!
echo "      Background PID: $FINERACT_BG_PID"
echo ""
echo "      Waiting for startup (may take 90-120 seconds)..."

# Poll until API responds or timeout (3 minutes)
TIMEOUT=300
ELAPSED=0
while [ $ELAPSED -lt $TIMEOUT ]; do
  sleep 10
  ELAPSED=$((ELAPSED + 10))
  HTTP_CODE=$(curl -k -s -o /dev/null -w "%{http_code}" "$FINERACT_URL" \
    -H "Fineract-Platform-TenantId: default" \
    -H "Authorization: $FINERACT_AUTH" 2>/dev/null || echo "000")
  if [ "$HTTP_CODE" = "200" ]; then
    break
  fi
  # Check for errors in log
  if grep -q "APPLICATION FAILED TO START\|BUILD FAILED" "$LOG_FILE" 2>/dev/null; then
    echo ""
    echo "ERROR: Fineract failed to start. Check log: $LOG_FILE"
    tail -20 "$LOG_FILE"
    exit 1
  fi
  printf "      ...%ds elapsed\n" "$ELAPSED"
done

# -----------------------------------------------------------------------------
# Final status
# -----------------------------------------------------------------------------
echo ""
if [ "$HTTP_CODE" = "200" ]; then
  echo "=========================================="
  echo " Status : RUNNING"
  echo " HTTPS  : https://localhost:8443/fineract-provider/api/v1/"
  echo " Login  : mifos / password"
  echo " Tenant : default (header: Fineract-Platform-TenantId: default)"
  echo " DB     : PostgreSQL localhost:5432 | postgres/postgres"
  echo " Log    : $LOG_FILE"
  echo "=========================================="
  echo ""
  echo " Quick test:"
  echo "   curl -k https://localhost:8443/fineract-provider/api/v1/offices \\"
  echo "     -H 'Fineract-Platform-TenantId: default' \\"
  echo "     -H 'Authorization: Basic bWlmb3M6cGFzc3dvcmQ='"
  echo ""
else
  echo "ERROR: Fineract did not respond after ${TIMEOUT}s. Check log: $LOG_FILE"
  tail -30 "$LOG_FILE"
  exit 1
fi

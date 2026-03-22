# Apache Fineract - Local PostgreSQL Setup

## Prerequisites

- **Java 21+** (Zulu OpenJDK recommended)
- **PostgreSQL 14+** running locally on port 5432
- **Gradle** (included via wrapper `./gradlew`)

## Quick Start

### 1. Setup PostgreSQL Databases

Run the setup script (one-time):

```bash
./setup-postgresql-local.sh
```

Or manually create the databases:

```sql
CREATE DATABASE fineract_tenants;
CREATE DATABASE fineract_default;
GRANT ALL PRIVILEGES ON DATABASE fineract_tenants TO postgres;
GRANT ALL PRIVILEGES ON DATABASE fineract_default TO postgres;
\c fineract_tenants
GRANT ALL ON SCHEMA public TO postgres;
\c fineract_default
GRANT ALL ON SCHEMA public TO postgres;
```

### 2. Configure Environment

The `.env.postgresql` file contains all configuration. Key settings:

| Variable | Default | Description |
|----------|---------|-------------|
| `FINERACT_HIKARI_JDBC_URL` | `jdbc:postgresql://localhost:5432/fineract_tenants` | Tenant store DB URL |
| `FINERACT_HIKARI_USERNAME` | `postgres` | DB username |
| `FINERACT_HIKARI_PASSWORD` | `postgres` | DB password |
| `FINERACT_DEFAULT_TENANTDB_NAME` | `fineract_default` | Default tenant DB name |
| `FINERACT_SERVER_SSL_ENABLED` | `false` | Disable SSL for local dev |

### 3. Run Fineract

Using the startup script:

```bash
./run-postgresql-local.sh
```

Or manually with environment variables:

```bash
# Load env vars
set -a && source .env.postgresql && set +a

# Start Fineract
./gradlew :fineract-provider:bootRun --no-daemon
```

### 4. Access the API

Once started, the API is available at:

- **HTTP**: `http://localhost:8080/fineract-provider/api/v1/`
- **HTTPS**: `https://localhost:8443/fineract-provider/api/v1/` (if SSL enabled)

Default credentials:
- **Username**: `mifos`
- **Password**: `password`
- **Tenant ID**: `default`

Example API call:

```bash
curl -X GET "http://localhost:8080/fineract-provider/api/v1/offices" \
  -H "Fineract-Platform-TenantId: default" \
  -H "Authorization: Basic bWlmb3M6cGFzc3dvcmQ="
```

## Troubleshooting

### Connection Refused
Ensure PostgreSQL is running:
```bash
pg_isready -h localhost -p 5432
```

### Wrong Driver (MariaDB instead of PostgreSQL)
Make sure `FINERACT_HIKARI_DRIVER_SOURCE_CLASS_NAME=org.postgresql.Driver` is exported before starting Fineract. The default in `application.properties` is MariaDB.

### Database Does Not Exist
Run `./setup-postgresql-local.sh` or create databases manually (see step 1).

### Liquibase Migration Errors
If starting fresh, ensure the databases are empty. Drop and recreate if needed:
```sql
DROP DATABASE IF EXISTS fineract_tenants;
DROP DATABASE IF EXISTS fineract_default;
CREATE DATABASE fineract_tenants;
CREATE DATABASE fineract_default;
```

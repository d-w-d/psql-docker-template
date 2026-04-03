#!/bin/bash
set -euo pipefail

# This script runs only on first initialization when PGDATA is empty.
# It creates an application role and database when APP_DB_* vars are provided.

if [[ -z "${APP_DB_USER:-}" || -z "${APP_DB_PASSWORD:-}" || -z "${APP_DB_NAME:-}" ]]; then
  echo "initdb: APP_DB_USER / APP_DB_PASSWORD / APP_DB_NAME not fully set; skipping app role/database creation"
  exit 0
fi

echo "initdb: ensuring app role '${APP_DB_USER}' and database '${APP_DB_NAME}' exist"

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname postgres \
  -v app_user="$APP_DB_USER" \
  -v app_password="$APP_DB_PASSWORD" \
  -v app_db="$APP_DB_NAME" <<'EOSQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'app_user', :'app_password')
WHERE NOT EXISTS (
  SELECT 1 FROM pg_catalog.pg_roles WHERE rolname = :'app_user'
)\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'app_db', :'app_user')
WHERE NOT EXISTS (
  SELECT 1 FROM pg_database WHERE datname = :'app_db'
)\gexec

ALTER DATABASE :"app_db" OWNER TO :"app_user";
GRANT ALL PRIVILEGES ON DATABASE :"app_db" TO :"app_user";
\connect :"app_db"
ALTER SCHEMA public OWNER TO :"app_user";
GRANT ALL ON SCHEMA public TO :"app_user";
EOSQL

echo "initdb: app role/database provisioning complete"

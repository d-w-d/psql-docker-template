# POSTGRESQL IN DOCKER (SERVER-ONLY)

This repository provides a simple, opinionated way to run PostgreSQL in Docker on a VM. It is designed for workloads like WordPress running on the same VM.

Highlights:

- Data is persisted via a volume mounted at `./datadir`.
- PostgreSQL config from `./configdir/` is mounted into the server (`/etc/postgresql/`).
- A single PostgreSQL superuser account (`postgres`, by default) is available for administrative tasks (you can create additional roles/users per your needs).

Repository layout:

- `docker-compose.yml` - defines the `db` service (`postgres:16.4`).
- `datadir/` - persistent PostgreSQL data (mounted into `db`).
- `configdir/` - PostgreSQL configuration mounted into the server (`/etc/postgresql/`).
- `configdir/pg_hba.conf` - client authentication rules (source IP/CIDR + auth method).
- `initdb/` - first-run initialization scripts mounted into `/docker-entrypoint-initdb.d/`.
- `_psql_connect` - helper to connect to PostgreSQL from the host.
- `_mysql_connect` - backward-compatible alias that forwards to `_psql_connect`.
- `.env-template` - environment template you copy to `.env`.

## Quick Start (on a VM)

Prerequisites:

- Docker and the Docker Compose plugin installed.

1. Clone this repo on your VM and configure environment:

```bash
git clone https://example.com/your/postgres-docker-template.git
cd postgres-docker-template
cp -n .env-template .env
# Edit .env and set:
#   POSTGRES_PASSWORD       (superuser password)
#   APP_DB_USER             (normal app user)
#   APP_DB_PASSWORD         (normal app user password)
#   APP_DB_NAME             (application database)
```

2. If you previously used this folder for MySQL, reset or rename `./datadir` before first PostgreSQL startup.

MySQL and PostgreSQL data directories are not compatible.

3. Start services:

```bash
docker compose up -d
```

## Starting, Stopping, and Connecting

- Start: `docker compose up -d`
- Stop: `docker compose down`
- Connect from the host:

```bash
./_psql_connect
```

Equivalent direct command:

```bash
PGPASSWORD='<password>' psql -h 127.0.0.1 -p 5432 -U postgres -d postgres
```

## Recommended Bootstrap Pattern (Superuser + App User)

This template supports a best-practice bootstrap:

- Superuser for admin tasks: `POSTGRES_USER` + `POSTGRES_PASSWORD`
- Normal application user: `APP_DB_USER` + `APP_DB_PASSWORD`
- Application database: `APP_DB_NAME` (owned by `APP_DB_USER`)

On first startup only (when `./datadir/` is empty), `initdb/10-create-app-role-and-db.sh` will create the app role and DB automatically if all `APP_DB_*` variables are set.

## Optional: first-run initialization via official PostgreSQL image

The official PostgreSQL image supports one-time initialization on the very first container start (i.e., when `./datadir/` is empty) using environment variables:

- `POSTGRES_USER`
- `POSTGRES_PASSWORD` (required)
- `POSTGRES_DB`

This repository keeps defaults minimal and multi-tenant-friendly. If you want a specific initial superuser/db, add these variables to your local `.env`. Example:

```env
POSTGRES_USER='postgres'
POSTGRES_PASSWORD='change-me'
POSTGRES_DB='postgres'
APP_DB_USER='my_app'
APP_DB_PASSWORD='strong_password_here'
APP_DB_NAME='my_app_db'
```

Notes:

- These initialization variables only take effect when the data directory is empty (first run).
- If you've already started the server once, remove or rename `./datadir/` to trigger initialization (be careful - this destroys data).
- `APP_DB_*` variables are handled by this repo's init script and also only apply on first run.

## PostgreSQL Config Best Practices

Server config in `configdir/postgresql.conf` is mounted into `/etc/postgresql/postgresql.conf` in the container. This repo includes conservative defaults such as:

- UTF-8 client encoding (`client_encoding = 'UTF8'`)
- `scram-sha-256` password hashing
- conservative logging defaults

### How to create a user and DB

- If you set `APP_DB_USER`, `APP_DB_PASSWORD`, and `APP_DB_NAME` before first startup, the role/db are created automatically.

- Connect to PostgreSQL using the helper:

```bash
./_psql_connect
```

- Manual SQL (if you skipped automatic init):

```sql
CREATE ROLE my_app LOGIN PASSWORD 'strong_password_here';
CREATE DATABASE my_app_db OWNER my_app;
```

## Networking Notes

- The compose file uses `network_mode: host`.
- PostgreSQL listens on port `5432`.
- `POSTGRES_LISTEN_ADDRESSES` controls which host interfaces PostgreSQL binds to.
  - Default: `*` (all IPv4/IPv6 interfaces)
  - Example for local + docker bridge: `127.0.0.1,172.17.0.1`
- `configdir/pg_hba.conf` controls which source IP ranges are allowed to authenticate.
  - Local socket auth is set to `trust` to avoid bootstrap failures when `POSTGRES_USER` is customized.
  - This template currently allows `0.0.0.0/0` and `::/0` with `scram-sha-256`.
  - For production, restrict those CIDRs to trusted sources.

See `README.networking101.md` for a detailed explanation of interfaces, binding, and troubleshooting.

## EC2 Reachability Checklist

If you want to connect from your laptop to PostgreSQL running on EC2:

Important: do not assume an Ubuntu EC2 host has no firewall rules. `ufw` may be active and can block port `5432` even when the EC2 security group allows it.

1. `POSTGRES_LISTEN_ADDRESSES='*'` in `.env` (already default in this template).
2. `configdir/pg_hba.conf` has a matching `host` rule for your source IP/CIDR.
3. EC2 security group allows inbound TCP 5432 from your source IP/CIDR.
4. NACLs and host firewall (`ufw`/iptables) allow 5432.
5. Use the EC2 public IP or DNS from your laptop, for example:

```bash
PGPASSWORD='<password>' psql -h <ec2-public-ip-or-dns> -p 5432 -U postgres -d postgres
```

## Misc Notes

- If you are on macOS and using colima as your docker daemon, point Docker to that daemon:

```bash
export DOCKER_HOST="unix://$HOME/.colima/docker.sock"
```

- TCP connections are not encrypted by default unless TLS is configured for PostgreSQL clients and server.

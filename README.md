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
# Edit .env - minimally set:
#   POSTGRES_PASSWORD
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

## Default behavior: no additional roles/databases created

This template spins up a vanilla PostgreSQL server intended to host multiple databases and users. By default, the container:

- Does not create any non-superuser roles.
- Only requires you to set `POSTGRES_PASSWORD` in `.env`.
- Persists data in `./datadir/` so subsequent restarts reuse the same server state.

Create databases and roles yourself after the server starts, for example:

```sql
CREATE ROLE my_app LOGIN PASSWORD 'strong_password_here';
CREATE DATABASE my_app_db OWNER my_app;
```

## Optional: first-run initialization via official PostgreSQL image

The official PostgreSQL image supports one-time initialization on the very first container start (i.e., when `./datadir/` is empty) using environment variables:

- `POSTGRES_USER`
- `POSTGRES_PASSWORD` (required)
- `POSTGRES_DB`

This repository keeps defaults minimal and multi-tenant-friendly. If you want a specific initial superuser/db, add these variables to your local `.env`. Example:

```env
POSTGRES_USER='postgres'
POSTGRES_PASSWORD='change-me'
POSTGRES_DB='my_app_db'
```

Notes:

- These initialization variables only take effect when the data directory is empty (first run).
- If you've already started the server once, remove or rename `./datadir/` to trigger initialization (be careful - this destroys data).
- For multi-database hosting, it's perfectly fine to keep defaults and create databases/roles manually.

## PostgreSQL Config Best Practices

Server config in `configdir/postgresql.conf` is mounted into `/etc/postgresql/postgresql.conf` in the container. This repo includes conservative defaults such as:

- UTF-8 client encoding (`client_encoding = 'UTF8'`)
- `scram-sha-256` password hashing
- conservative logging defaults

### How to create a user and DB

- Connect to PostgreSQL using the helper:

```bash
./_psql_connect
```

- Create a role and database; replace `my_app_db` and `my_app` with your desired values:

```sql
CREATE ROLE my_app LOGIN PASSWORD 'strong_password_here';
CREATE DATABASE my_app_db OWNER my_app;
```

## Networking Notes

- The compose file uses `network_mode: host`.
- PostgreSQL listens on port `5432`.
- `POSTGRES_LISTEN_ADDRESSES` controls which host interfaces PostgreSQL binds to.
  - Default: `127.0.0.1` (localhost only)
  - Example for local + docker bridge: `127.0.0.1,172.17.0.1`
  - Example for all IPv4 interfaces: `*`

See `README.networking101.md` for a detailed explanation of interfaces, binding, and troubleshooting.

## Misc Notes

- If you are on macOS and using colima as your docker daemon, point Docker to that daemon:

```bash
export DOCKER_HOST="unix://$HOME/.colima/docker.sock"
```

- TCP connections are not encrypted by default unless TLS is configured for PostgreSQL clients and server.

# Networking 101: Interfaces, IP Addresses, and Listen Addresses

This guide explains the fundamental networking concepts you need to understand when connecting an app (running on host or Docker) to PostgreSQL.

## Table of Contents

- [The Mental Model](#the-mental-model)
- [Network Interfaces Explained](#network-interfaces-explained)
- [IP Addresses and Interfaces](#ip-addresses-and-interfaces)
- [What is Binding?](#what-is-binding)
- [The `listen_addresses` Setting](#the-listen_addresses-setting)
- [How Connections Work](#how-connections-work)
- [The Special Address `*`](#the-special-address-)
- [Docker `network_mode: host`](#docker-network_mode-host)
- [Two-Layer Security Model](#two-layer-security-model)
- [Common Scenarios](#common-scenarios)
- [Troubleshooting Guide](#troubleshooting-guide)

---

## The Mental Model

### Incorrect (Oversimplified) Model

- "A machine has an IP address"
- "192.168.1.100 is the machine's IP"
- "127.0.0.1 is just localhost"

### Correct (Technically Accurate) Model

- A machine has multiple network interfaces (physical or virtual)
- Each interface has one or more IP addresses
- A process binds to specific interface(s) by specifying IP address(es)
- Clients connect to a specific IP address, which routes to a specific interface
- The PostgreSQL process must be listening on that interface to receive the connection

---

## Network Interfaces Explained

### What is a Network Interface?

A network interface is a physical or virtual network adapter that allows a machine to communicate on a network.

Think of interfaces as different doors into your machine:

- Each door has its own IP address
- A process (like PostgreSQL) can choose which door(s) to monitor
- Clients must connect to the right door to reach the process

### Common Interfaces

| Interface | Type                    | Typical IP      | Purpose                                        |
| --------- | ----------------------- | --------------- | ---------------------------------------------- |
| `lo`      | Virtual (loopback)      | `127.0.0.1`     | Internal communication within the same machine |
| `eth0`    | Physical (Ethernet)     | `192.168.1.100` | LAN/WAN communication                          |
| `wlan0`   | Physical (WiFi)         | `192.168.1.50`  | Wireless network communication                 |
| `docker0` | Virtual (Docker bridge) | `172.17.0.1`    | Communication between Docker and host          |

### View Your Interfaces

```bash
# Linux/macOS
ip addr show
# OR
ifconfig

# Example output:
# lo: 127.0.0.1 (loopback)
# eth0: 192.168.1.100 (LAN)
# docker0: 172.17.0.1 (Docker bridge)
```

---

## IP Addresses and Interfaces

### Key Concept

> An IP address is assigned to a network interface, not to "the machine" as a whole.

Your machine might have:

- `127.0.0.1` on the `lo` interface
- `192.168.1.100` on the `eth0` interface
- `172.17.0.1` on the `docker0` interface

These are different addresses on different interfaces.

### Routing

When a packet arrives with destination IP `192.168.1.100`:

1. The OS routes it to the `eth0` interface
2. Any process listening on `192.168.1.100` can receive it
3. Processes not listening on `192.168.1.100` will not see it

---

## What is Binding?

### Definition

Binding = a process attaching itself to a specific IP address (interface) and port to listen for incoming connections.

### Example

```bash
# PostgreSQL listens on 127.0.0.1:5432
# This means:
# - PostgreSQL monitors the 'lo' interface (127.0.0.1)
# - PostgreSQL listens on port 5432
# - Only packets sent to 127.0.0.1:5432 reach PostgreSQL
```

### What Happens When You Bind

1. Process requests to bind to `192.168.1.100:5432`
2. OS reserves that IP:port for the process
3. OS routes incoming packets to `192.168.1.100:5432` to that process
4. Packets to other IPs (for example `127.0.0.1:5432`) are not routed to the process

---

## The `listen_addresses` Setting

### What It Controls

The `listen_addresses` setting in PostgreSQL specifies which IP address(es) the server listens on.

### Options

#### 1. Listen on localhost only

```conf
listen_addresses = '127.0.0.1'
```

- PostgreSQL listens only on loopback
- Clients must connect to `127.0.0.1:5432`
- Connections to `192.168.1.100:5432` fail (PostgreSQL not listening there)

#### 2. Listen on one specific IP

```conf
listen_addresses = '192.168.1.100'
```

- PostgreSQL listens only on that interface
- Clients must connect to `192.168.1.100:5432`
- Connections to `127.0.0.1:5432` fail

#### 3. Listen on all interfaces

```conf
listen_addresses = '*'
```

- PostgreSQL listens on all interfaces
- Clients can connect via loopback, LAN, docker bridge, and any other interface

#### 4. Listen on multiple specific IPs

```conf
listen_addresses = '127.0.0.1,192.168.1.100,172.17.0.1'
```

- PostgreSQL listens only on the listed interfaces
- More precise than `*`

---

## How Connections Work

### Step-by-Step Connection Process

Scenario: client on `192.168.1.50` wants to connect to PostgreSQL on `192.168.1.100`

1. Client initiates connection:

```bash
psql "host=192.168.1.100 port=5432 user=app_user dbname=app_db"
```

2. Client sends packet:

- Source: `192.168.1.50:random_port`
- Destination: `192.168.1.100:5432`

3. Packet arrives at server:

- OS receives packet on `eth0` (bound to `192.168.1.100`)

4. OS checks for listening process:

- Is there a process bound to `192.168.1.100:5432`?
- Yes -> route packet to PostgreSQL -> connection can proceed
- No -> connection refused

5. PostgreSQL must be listening on that IP:

- If `listen_addresses` includes `192.168.1.100` -> network path is valid
- If `listen_addresses = '127.0.0.1'` -> PostgreSQL never receives that LAN connection

---

## The Special Address `*`

`*` in PostgreSQL means all available network interfaces.

```conf
listen_addresses = '*'
```

Practical effect:

```bash
# Any of these may work (if pg_hba + firewall also allow):
psql "host=127.0.0.1 port=5432 user=... dbname=..."
psql "host=192.168.1.100 port=5432 user=... dbname=..."
psql "host=172.17.0.1 port=5432 user=... dbname=..."
```

Security consideration:

- `*` is flexible but broad
- Prefer specific addresses where possible
- Enforce firewall rules and strict `pg_hba.conf` entries
- If deployed to cloud VMs, also restrict security groups to trusted source IP ranges

---

## Docker `network_mode: host`

When a Docker container uses `network_mode: host`:

- The container shares the host network namespace
- The container sees the same interfaces as the host
- There is no network isolation between host and container

Example host interfaces:

```text
lo: 127.0.0.1
eth0: 192.168.1.100
docker0: 172.17.0.1
```

PostgreSQL in Docker with `network_mode: host` and `listen_addresses='*'`:

- PostgreSQL binds to all host interfaces
- PostgreSQL is reachable at:
  - `127.0.0.1:5432`
  - `192.168.1.100:5432`
  - `172.17.0.1:5432`

---

## Two-Layer Security Model

PostgreSQL uses two critical layers of access control:

### Layer 1: Network Layer (`listen_addresses`)

Controls which interfaces PostgreSQL listens on.

### Layer 2: Authentication/Authorization Layer (`pg_hba.conf` + roles)

Controls which clients can authenticate from which source ranges, and what they can do after login.

Example `pg_hba.conf` line:

```conf
host    all    all    172.17.0.0/16    scram-sha-256
```

In this repository, `pg_hba.conf` is versioned at `configdir/pg_hba.conf` and loaded by PostgreSQL using:

```text
-c hba_file=/etc/postgresql/pg_hba.conf
```

Example role/database setup:

```sql
CREATE ROLE wpuser LOGIN PASSWORD 'password';
CREATE DATABASE wordpress OWNER wpuser;
```

Both layers must allow the connection:

```text
Client Connection Attempt
         |
[Layer 1: listen_addresses]
  Is PostgreSQL listening on destination IP?
    NO -> Connection refused
    YES
         |
[Layer 2: pg_hba.conf + role auth]
  Is this source/user allowed and authenticated?
    NO -> Access denied
    YES
         |
Connection successful
```

---

## Common Scenarios

### Scenario 1: PostgreSQL on host, app in Docker (bridge network)

PostgreSQL config:

```conf
listen_addresses = '*'
# OR more constrained:
# listen_addresses = '192.168.1.100,172.17.0.1'
```

App config:

```bash
APP_DB_HOST=192.168.1.100
APP_DB_PORT=5432
# OR
APP_DB_HOST=172.17.0.1
APP_DB_PORT=5432
```

`pg_hba.conf` example:

```conf
host    app_db    app_user    172.17.0.0/16    scram-sha-256
```

### Scenario 2: Both PostgreSQL and app in Docker with `network_mode: host`

PostgreSQL config:

```conf
listen_addresses = '127.0.0.1'
# OR
listen_addresses = '*'
```

App config:

```bash
APP_DB_HOST=127.0.0.1
APP_DB_PORT=5432
```

`pg_hba.conf` example:

```conf
host    app_db    app_user    127.0.0.1/32    scram-sha-256
```

### Scenario 3: PostgreSQL on server A, app on server B

- Server A: `192.168.1.100`
- Server B: `192.168.1.200`

PostgreSQL config:

```conf
listen_addresses = '192.168.1.100'
# OR '*'
```

App config:

```bash
APP_DB_HOST=192.168.1.100
APP_DB_PORT=5432
```

`pg_hba.conf` example:

```conf
host    app_db    app_user    192.168.1.200/32    scram-sha-256
```

---

## Troubleshooting Guide

### Error: connection refused

Meaning: no process is listening on the destination IP:port.

Possible causes:

1. PostgreSQL not running.
2. Wrong destination IP.
3. `listen_addresses` does not include the target interface.

Check:

```bash
docker compose ps
sudo ss -tlnp | grep 5432
```

### Error: no pg_hba.conf entry

Meaning: connection reached PostgreSQL but client source/user/db is not allowed by `pg_hba.conf`.

Solution:

- Add/adjust a matching `host` rule.
- Reload PostgreSQL config.

### Error: password authentication failed for user

Meaning: network path works, but credentials or auth method are wrong.

Check:

- Correct username/password.
- Role has `LOGIN`.
- `pg_hba.conf` auth method matches your password setup.

### Error: could not translate host name `host.docker.internal`

Meaning: host alias resolution is not available in your environment.

Solution:

- Use actual host IP (for example `192.168.1.100`) or docker bridge gateway (`172.17.0.1`).

### Debugging commands

Check interfaces and IPs:

```bash
ip addr show
# or
ifconfig
```

Check PostgreSQL runtime settings:

```bash
PGPASSWORD='<password>' psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "SHOW listen_addresses;"
PGPASSWORD='<password>' psql -h 127.0.0.1 -p 5432 -U postgres -d postgres -c "SHOW port;"
```

Test from another container:

```bash
docker run --rm -it postgres:16 psql "host=192.168.1.100 port=5432 user=app_user dbname=app_db"
```

---

## Summary: Key Takeaways

1. Interfaces are network adapters, each with IP address(es)
2. Binding means listening on specific IP:port combinations
3. `listen_addresses` controls where PostgreSQL listens
4. Clients must connect to an IP PostgreSQL is actually listening on
5. `*` means all interfaces and should be paired with strict auth/firewall
6. Access control is layered: network listen + `pg_hba.conf` + role permissions
7. `network_mode: host` makes containers share host interfaces

---

## Further Reading

- [PostgreSQL Runtime Config (`listen_addresses`)](https://www.postgresql.org/docs/current/runtime-config-connection.html)
- [PostgreSQL Client Authentication (`pg_hba.conf`)](https://www.postgresql.org/docs/current/auth-pg-hba-conf.html)
- [Docker Networking Overview](https://docs.docker.com/network/)

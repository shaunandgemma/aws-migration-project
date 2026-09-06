# Technical Discovery

## Purpose

This document consolidates the verified technical discovery findings for the simulated on-premises source environment.

Detailed raw evidence and server-specific discovery reports are stored separately. This document is intended to provide a clear technical view of the current source architecture, dependencies, security posture, operational risks, and migration-relevant findings.

---

# 1. Source Environment Summary

The source environment consists of three Ubuntu virtual machines:

| Server | Role | Private IP | Primary Function |
|---|---|---|---|
| `onprem-app01` | Application server | `192.168.56.10` | Nginx, Gunicorn and Flask Customer Portal |
| `onprem-db01` | Database server | `192.168.56.20` | MySQL Community Server |
| `onprem-file01` | File server | `192.168.56.30` | NFS shared-file storage |

All three servers run Ubuntu 24.04.4 LTS in Oracle VirtualBox.

---

# 2. Application Server — `onprem-app01`

## Platform

| Item | Verified Value |
|---|---|
| Hostname | `onprem-app01` |
| Operating system | Ubuntu 24.04.4 LTS |
| Architecture | x86-64 |
| Kernel | Linux 6.8.0-138-generic |
| Virtualisation | Oracle VirtualBox |
| CPU | 2 vCPU |
| RAM | 1.9 GiB |
| Virtual disk | 20 GB |
| Root filesystem | 9.8 GB |
| Root utilisation | 54% |
| Application directory size | ~88 MB |

## Network Configuration

| Interface | Address | Purpose |
|---|---|---|
| `enp0s3` | `10.0.2.15/24` | NAT / outbound connectivity |
| `enp0s8` | `192.168.56.10/24` | Private on-premises network |

Default route:

`10.0.2.2` via `enp0s3`

The `192.168.56.0/24` network is directly reachable through `enp0s8`.

## Application Stack

The Customer Portal uses:

- Python 3.12.3
- Flask 3.1.3
- Gunicorn 26.2.0
- Nginx 1.24.0
- `mysql-connector-python` 26.7.0

Application path:

`/opt/legacy-app`

Python virtual environment:

`/opt/legacy-app/venv`

Systemd service:

`legacy-app.service`

## Request Flow

Verified request path:

`Client -> Nginx :80 -> Gunicorn 127.0.0.1:5000 -> Flask -> MySQL`

Nginx listens on TCP port 80 and proxies requests to Gunicorn on:

`127.0.0.1:5000`

Gunicorn is therefore not directly exposed to the network.

## Application Service

Verified service configuration:

- Service user: `shaun`
- Working directory: `/opt/legacy-app`
- Environment file: `/etc/legacy-app.env`
- Gunicorn bind address: `127.0.0.1:5000`
- Restart policy: `always`
- Service is active and enabled

The credential file `/etc/legacy-app.env` is:

- Owned by `root:root`
- Permission mode `600`
- Not readable by normal users

The database password is loaded from the `DB_PASSWORD` environment variable and is not hard-coded in `app.py`.

## Database Dependency

Application code confirms:

- Database host: `192.168.56.20`
- Database: `legacy_app`
- Database user: `legacy_app_user`

Network traffic confirmed MySQL communication from:

`192.168.56.10 -> 192.168.56.20:3306`

The application creates short-lived database connections.

### Database Transport Encryption

An application-style connection using the same Python environment, MySQL Connector configuration, application account, and environment-supplied password was tested.

Verified:

- TLS version: `TLSv1.3`
- TLS cipher: `TLS_AES_256_GCM_SHA384`

The application does not explicitly configure TLS parameters in `app.py`; MySQL Connector negotiates TLS automatically.

The database server does not currently enforce TLS globally because `require_secure_transport = OFF`.

## NFS Mount

The application server has the following persistent NFS mount:

`192.168.56.30:/srv/legacy-files -> /mnt/legacy-files`

Verified client configuration includes:

- NFSv4.2
- TCP
- Read/write
- `hard`
- `sec=sys`
- `rsize=262144`
- `wsize=262144`

The mount is also configured in `/etc/fstab` with:

- `_netdev`
- `nofail`

## NFS Application Dependency Finding

The NFS mount and active network connection are technically verified.

However, repeated application-code searches found no references to:

- `/mnt/legacy-files`
- `legacy-files`
- `uploads`
- `invoice`
- `contract`
- `report`

No process had an open file on the NFS share when checked with `lsof`.

Therefore:

> The application server is connected to and mounts the NFS share, but direct use of the share by the Flask application has not been technically verified.

This differs from the customer-provided dependency information and remains a discovery discrepancy.

## Host Security

Verified host firewall state:

- UFW: inactive
- nftables: no rules detected
- iptables INPUT policy: ACCEPT
- iptables FORWARD policy: ACCEPT
- iptables OUTPUT policy: ACCEPT

SSH listens on TCP port 22 on all interfaces.

Nginx listens on TCP port 80 on all interfaces.

No effective host-level firewall filtering was identified.

## Scheduled Jobs and Health

- No user crontab for `shaun`
- No root crontab
- Systemd timers are primarily standard operating-system maintenance
- No application-specific scheduled jobs identified
- No recent Nginx errors found
- No application errors identified in reviewed `legacy-app` logs
- Application and Nginx services are healthy

## Application Baseline

Pre-migration HTTP baseline:

- HTTP status: `200 OK`
- Nginx serving successfully
- Application displayed: `Customers in database: 53`

This baseline should be used during migration validation.

---

# 3. Database Server — `onprem-db01`

## Platform

| Item | Verified Value |
|---|---|
| Hostname | `onprem-db01` |
| Operating system | Ubuntu 24.04.4 LTS |
| CPU | 2 vCPU |
| RAM | 1.9 GiB |
| Virtual disk | 20 GB |
| Private IP | `192.168.56.20` |
| Database platform | MySQL Community Server |
| MySQL version | `8.0.46-0ubuntu0.24.04.4` |
| Database listener | `192.168.56.20:3306` |

## Application Database

Application database:

`legacy_app`

Tables:

- `customers`
- `orders`

Verified row counts:

| Table | Rows |
|---|---:|
| `customers` | 53 |
| `orders` | 100 |

Approximate database size:

**0.05 MB**

Both tables use:

- InnoDB
- `utf8mb4`
- `utf8mb4_0900_ai_ci`

Foreign-key relationship:

`orders.customer_id -> customers.id`

## Application Database Account

Application account:

`legacy_app_user@192.168.56.10`

Authentication:

`caching_sha2_password`

Permissions on `legacy_app`:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

No schema-management or administrative privileges were identified.

## Binary Logging and Migration Readiness

Verified:

- Binary logging: ON
- Binlog format: `ROW`
- Binlog row image: `FULL`
- Binlog retention: 30 days
- Server ID: `1`
- GTID mode: OFF
- No replica configured

The binary-log configuration is favourable for a possible CDC-based migration approach such as AWS DMS.

## Availability

`onprem-db01` is a standalone writable MySQL server.

No database-level replication or automatic failover configuration was identified.

This represents a single point of failure.

## TLS

MySQL supports TLS.

Application-style connections were verified to negotiate TLS 1.3.

However:

`require_secure_transport = OFF`

Therefore encrypted transport works but is not enforced for every possible client.

## Backup Discovery

Detected backup utilities:

- `mysqldump`
- `mysqlpump`

Not detected:

- `mysqlsh`
- `xtrabackup`

No automated MySQL backup process was technically verified in the cron, systemd, `/usr/local/bin`, or `/opt` locations checked.

The customer stated that monthly database backups were believed to exist, but the existence, location, retention, and recoverability of those backups remain unknown.

## Automatic Update Risk

During discovery, Ubuntu `unattended-upgrade` upgraded MySQL from:

`8.0.46-0ubuntu0.24.04.3`

to:

`8.0.46-0ubuntu0.24.04.4`

MySQL performed a controlled shutdown and restart during the upgrade.

This demonstrates that automatic operating-system package updates can interrupt database availability outside a manually controlled maintenance window.

This is particularly important against the customer requirements:

- RPO: 0 / zero data loss
- RTO: 1 hour

## Detailed Database Discovery

See:

`onprem-db01-mysql-discovery.md`

Raw Linux discovery evidence:

`onprem-db01-discovery-full.txt`

---

# 4. File Server — `onprem-file01`

## Platform

| Item | Verified Value |
|---|---|
| Hostname | `onprem-file01` |
| Operating system | Ubuntu 24.04.4 LTS |
| CPU | 2 vCPU |
| RAM | 1.9 GiB |
| Virtual disk | 20 GB |
| Private IP | `192.168.56.30` |
| File-sharing protocol | NFS |

## NFS Export

Exported directory:

`/srv/legacy-files`

Permitted client:

`192.168.56.10`

Configured export:

```text
/srv/legacy-files 192.168.56.10(rw,sync,no_subtree_check,all_squash)
```

Verified active options include:

- `rw`
- `sync`
- `no_subtree_check`
- `sec=sys`
- `root_squash`
- `all_squash`

Supported NFS versions:

- NFSv3
- NFSv4
- NFSv4.1
- NFSv4.2

## Active Client

An established NFS connection was observed:

`192.168.56.10 -> 192.168.56.30:2049`

The application server mounts the share using NFSv4.2.

## Data Volume

Measured data under `/srv/legacy-files`:

- Disk usage: approximately 24 KB
- Files: 4
- Directories: 2
- Symbolic links: 0
- Multiple-hard-link files: none detected

All discovered files were ASCII text.

File ownership:

`nobody:nogroup`

This is consistent with the use of `all_squash`.

## Customer Data-Size Discrepancy

Customer estimate:

Approximately **2 GB** of shared files.

Technical discovery:

Approximately **24 KB** exists under `/srv/legacy-files`.

This discrepancy must be resolved before final migration planning.

Possible explanations include:

- Customer estimate is outdated
- Additional data exists elsewhere
- The source lab contains only representative data

No conclusion has been assumed.

## Backup Discovery

`rsync` is installed.

No dedicated file-share backup, snapshot, or scheduled `rsync` process was technically verified.

No automated backup of `/srv/legacy-files` has currently been confirmed.

## Security

Verified:

- UFW inactive
- No nftables rules detected
- iptables INPUT policy ACCEPT
- NFS/RPC services listen on multiple interfaces
- NFS export itself is restricted to `192.168.56.10`
- NFS security uses `sec=sys`

`sec=sys` relies on traditional Unix UID/GID identity rather than stronger Kerberos-based NFS authentication.

## NFS Health

- No failed systemd units identified
- No NFS server errors or warnings identified in the reviewed service journals
- One NFS block-layout startup warning was observed, but no evidence showed an impact to the active NFS service

## Detailed File-Server Discovery

See:

`onprem-file01-nfs-discovery.md`

Raw Linux discovery evidence:

`onprem-file01-discovery-full.txt`

---

# 5. Verified Dependency Map

```text
                         HTTP :80
                            |
                            v
                    +----------------+
                    | onprem-app01   |
                    | 192.168.56.10  |
                    | Nginx          |
                    | Gunicorn       |
                    | Flask          |
                    +-------+--------+
                            |
               +------------+-------------+
               |                          |
               | MySQL :3306              | NFSv4.2 :2049
               v                          v
      +----------------+        +----------------+
      | onprem-db01    |        | onprem-file01  |
      | 192.168.56.20  |        | 192.168.56.30  |
      | MySQL          |        | NFS             |
      +----------------+        +----------------+
```

### Confirmed dependency

`onprem-app01 -> onprem-db01`

The Flask application directly queries MySQL.

### Infrastructure dependency confirmed, application dependency unverified

`onprem-app01 -> onprem-file01`

The NFS mount and network connection exist, but the Flask application's direct use of the share has not been verified.

---

# 6. Discovery Discrepancies and Unknowns

## Application-to-file-server dependency

Customer statement:

The application uses the file server.

Technical finding:

The NFS mount exists and is active, but no application-code reference or active application file handle was identified.

Status:

**Unverified application dependency**

## File-share size

Customer estimate:

Approximately 2 GB.

Technical finding:

Approximately 24 KB.

Status:

**Significant discrepancy requiring clarification**

## Database backups

Customer statement:

Monthly backups are believed to exist but have been neglected.

Technical finding:

No automated MySQL backup process was identified.

Status:

**Backup existence, retention, and restore capability unknown**

## File-share backups

Technical finding:

No automated backup or snapshot mechanism for `/srv/legacy-files` was identified.

Status:

**No verified business-file backup**

---

# 7. Source Environment Risks

The following migration-relevant source risks were identified:

1. The application server is a single instance with no application-level redundancy.
2. The MySQL database is a single writable server with no replication or failover.
3. The NFS file server has no verified replica or failover mechanism.
4. Host-level firewall protection is not effectively configured on the discovered servers.
5. MySQL TLS is supported and used by the application-style connection but is not globally enforced.
6. No automated MySQL database backup process has been verified.
7. No automated business-file backup process has been verified.
8. Ubuntu unattended upgrades can restart MySQL outside a controlled maintenance window.
9. Customer-provided information contains unresolved differences from technical discovery.
10. Any single-server failure could affect the Customer Portal.

---

# 8. Migration-Relevant Technical Conclusions

The technical discovery indicates:

- The application is small and technically simple.
- The application server uses a conventional Nginx -> Gunicorn -> Flask stack.
- The MySQL schema is small and uncomplicated.
- Binary logging is already suitable for possible CDC-based database migration.
- Application-style MySQL connections successfully use TLS 1.3.
- The source database and file server lack verified resilient backup and failover mechanisms.
- The file share is technically available to the application server, but its direct application requirement is unresolved.
- Current host-level security controls are weak and should not be copied directly into the AWS target.
- The AWS target design should improve availability, backup, recovery, security, monitoring, and operational control rather than simply reproduce the existing three-server architecture.

No AWS target services are selected in this document. Service selection will be performed after the source assessment and migration strategy are completed.

---

# 9. Evidence Index

## Application Server

Raw automated discovery:

`onprem-app01-discovery-full.txt`

Manual application discovery is consolidated within this document.

## Database Server

Raw automated discovery:

`onprem-db01-discovery-full.txt`

Detailed MySQL discovery:

`onprem-db01-mysql-discovery.md`

## File Server

Raw automated discovery:

`onprem-file01-discovery-full.txt`

Detailed NFS discovery:

`onprem-file01-nfs-discovery.md`

---

# 10. Technical Discovery Status

| Server | Discovery Status |
|---|---|
| `onprem-app01` | Complete |
| `onprem-db01` | Complete |
| `onprem-file01` | Complete |

**Overall technical discovery status: COMPLETE**

The next phase is to consolidate the customer requirements and technical findings into a source assessment before selecting the AWS target architecture.

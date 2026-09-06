# ONPREM-DB01 — MySQL Technical Discovery

## Overview

| Item | Verified value |
|---|---|
| Server | `onprem-db01` |
| Purpose | Manual MySQL-specific technical discovery for the on-premises to AWS migration assessment |
| Database platform | MySQL Community Server |
| Current version | `8.0.46-0ubuntu0.24.04.4` |
| Service | `mysql.service` |
| Service state | Active / running |
| Database listener | `192.168.56.20:3306` |
| MySQL X Plugin | `127.0.0.1:33060` |
| Configured bind address | `192.168.56.20` |

> This document records verified database findings only. Passwords and credential values are intentionally excluded.

---

## 1. Database Inventory

Databases detected:

- `information_schema`
- `legacy_app`
- `mysql`
- `performance_schema`
- `sys`

The application database is `legacy_app`.

The remaining databases are standard MySQL system databases.

---

## 2. Application Tables

The `legacy_app` database contains two tables:

- `customers`
- `orders`

### `customers`

| Column | Type | Null | Key / behaviour |
|---|---|---|---|
| `id` | `INT` | No | Primary key, auto increment |
| `name` | `VARCHAR(100)` | No | — |
| `email` | `VARCHAR(150)` | No | — |
| `created_at` | `TIMESTAMP` | Yes | Default `CURRENT_TIMESTAMP` |

### `orders`

| Column | Type | Null | Key / behaviour |
|---|---|---|---|
| `id` | `INT` | No | Primary key, auto increment |
| `customer_id` | `INT` | No | Indexed, foreign key |
| `product_name` | `VARCHAR(100)` | No | — |
| `quantity` | `INT` | No | — |
| `total_amount` | `DECIMAL(10,2)` | No | — |
| `order_date` | `TIMESTAMP` | Yes | Default `CURRENT_TIMESTAMP` |

---

## 3. Table Relationships

Verified foreign-key relationship:

`orders.customer_id` → `customers.id`

Constraint: `orders_ibfk_1`

The `customer_id` column is indexed.

---

## 4. Storage Engine and Character Set

| Item | Value |
|---|---|
| `customers` engine | InnoDB |
| `customers` collation | `utf8mb4_0900_ai_ci` |
| `orders` engine | InnoDB |
| `orders` collation | `utf8mb4_0900_ai_ci` |
| Server character set | `utf8mb4` |
| Server collation | `utf8mb4_0900_ai_ci` |
| `lower_case_table_names` | `0` |

---

## 5. Data Volume

### Verified row counts

| Table | Rows |
|---|---:|
| `customers` | 53 |
| `orders` | 100 |

Approximate total application database size: **0.05 MB**

### Table-level storage

| Table | Data | Indexes |
|---|---:|---:|
| `customers` | ~0.016 MB | ~0 MB |
| `orders` | ~0.016 MB | ~0.016 MB |

---

## 6. Indexes

### `customers`

- `PRIMARY` → `id`

### `orders`

- `PRIMARY` → `id`
- `customer_id` → `customer_id`

The `customer_id` index supports the foreign-key relationship to `customers.id`.

---

## 7. MySQL Users and Access

### Application account

Account: `legacy_app_user@192.168.56.10`

Authentication plugin: `caching_sha2_password`

The account is restricted to connections originating from the application server IP `192.168.56.10`.

Verified permissions on `legacy_app`:

- `SELECT`
- `INSERT`
- `UPDATE`
- `DELETE`

No schema-management or administrative privileges were identified for the application account.

### Root account

Account: `root@localhost`

Authentication: `auth_socket`

Root is restricted to localhost.

### Other accounts detected

- `debian-sys-maint@localhost`
- `mysql.infoschema@localhost`
- `mysql.session@localhost`
- `mysql.sys@localhost`

No unexpected remotely accessible MySQL administrative account was identified.

---

## 8. Transaction Configuration

| Setting | Value |
|---|---|
| Transaction isolation | `REPEATABLE-READ` |
| `read_only` | `OFF` |
| `super_read_only` | `OFF` |

`onprem-db01` is operating as a writable database server.

---

## 9. Binary Logging

| Setting | Value |
|---|---|
| Binary logging | ON |
| Binary log format | `ROW` |
| Binary log row image | `FULL` |
| Binary log location | `/var/lib/mysql/binlog` |
| Binary log expiry | `2592000` seconds |
| Equivalent retention | 30 days |
| Server ID | `1` |

These settings are favourable for a possible change-data-capture migration approach such as AWS DMS.

---

## 10. Replication and High Availability

| Setting | Value |
|---|---|
| GTID mode | `OFF` |
| Replica status | No replica configuration returned |
| `read_only` | `OFF` |
| `super_read_only` | `OFF` |

Verified finding:

`onprem-db01` is a standalone writable MySQL database server.

No MySQL replica or database-level failover configuration was identified.

---

## 11. Connection Capacity

| Metric | Value |
|---|---:|
| Maximum configured connections | 151 |
| Threads connected during discovery | 1 |
| Maximum connections used since latest restart | 1 |

> MySQL had recently restarted because of an automatic package upgrade. `Max_used_connections = 1` therefore does not represent normal historical production workload.

---

## 12. Query Logging

| Setting | Value |
|---|---|
| Slow query log | OFF |
| Slow query log file | `/var/lib/mysql/onprem-db01-slow.log` |
| Long query threshold | 10 seconds |
| General query log | OFF |

No useful historical slow-query workload evidence is available from the configured MySQL slow query log.

---

## 13. TLS and Database Transport Security

### Server configuration

| Setting | Value |
|---|---|
| TLS support | Available |
| `have_ssl` | `YES` |
| `require_secure_transport` | `OFF` |

MySQL supports encrypted connections but does not require every client to use TLS.

### Application-to-database TLS verification

A test connection was created from `onprem-app01` using:

- The application's Python virtual environment
- `mysql.connector`
- The same database host
- The same `legacy_app_user` account
- The application's `DB_PASSWORD` environment variable

The password itself was not displayed or recorded.

Verified session encryption:

| Item | Value |
|---|---|
| TLS version | `TLSv1.3` |
| TLS cipher | `TLS_AES_256_GCM_SHA384` |

Application-style database connections successfully negotiate encrypted TLS 1.3 connectivity between `onprem-app01` and `onprem-db01`.

The application does not explicitly configure TLS parameters in `app.py`; TLS is negotiated automatically by MySQL Connector.

> `require_secure_transport = OFF`, so encrypted transport works for the application connection but is not enforced globally for every possible MySQL client.

---

## 14. Stored Database Objects

| Object type | Result |
|---|---|
| Triggers | None detected |
| Stored procedures/functions | None detected |
| Scheduled MySQL events | None detected |

This reduces database migration complexity.

---

## 15. Backup Discovery

### Backup utilities detected

- `/usr/bin/mysqldump`
- `/usr/bin/mysqlpump`

### Not detected

- `mysqlsh`
- `xtrabackup`

No MySQL backup job was identified in the locations checked:

- User/root cron locations
- Custom systemd service locations
- `/usr/local/bin`
- `/opt`

`dpkg-db-backup.timer` was detected, but this is an Ubuntu package-management database backup mechanism and **not** a backup of the `legacy_app` MySQL database.

### Customer statement

Monthly database backups are believed to exist but have been neglected.

### Technical discovery result

No automated MySQL backup mechanism has been verified.

The existence, location, retention and recoverability of any customer database backups therefore remain **unknown**.

---

## 16. Automatic Update Finding

During technical discovery, the MySQL administrative connection was unexpectedly lost.

Investigation confirmed that MySQL had not crashed. Ubuntu `unattended-upgrade` automatically upgraded MySQL from:

`8.0.46-0ubuntu0.24.04.3`

to:

`8.0.46-0ubuntu0.24.04.4`

APT history confirmed the MySQL package upgrade started at approximately **08:43 on 2026-09-01**.

MySQL performed a controlled shutdown and restart during the package upgrade.

### Operational risk

Automatic package updates can interrupt database availability outside a manually controlled maintenance window.

This is particularly relevant because the customer stated:

| Requirement | Target |
|---|---|
| RPO | 0 / zero data loss |
| RTO | 1 hour |

---

## 17. MySQL Warnings Observed

Warnings observed in the MySQL error log included:

- MySQL CA certificate is self-signed
- IP address `192.168.56.10` could not be reverse-resolved
- Root connection was forcibly closed during the automatic MySQL package restart

Temporary PID-file warnings were also observed during the package-upgrade process.

These occurred during temporary package-management MySQL processes and do not currently prove that the normal MySQL service uses `/tmp` for its PID file.

---

## 18. Migration-Relevant Findings

1. `legacy_app` is very small at approximately **0.05 MB**.
2. The application schema is simple:
   - 2 tables
   - 1 foreign-key relationship
   - no stored procedures
   - no triggers
   - no scheduled MySQL events
3. Both application tables use InnoDB.
4. Binary logging is enabled.
5. Binary logging uses `ROW` format with `FULL` row images.
6. Binary logs are configured for 30-day retention.
7. These settings are favourable for a possible CDC migration approach such as AWS DMS.
8. GTID replication is not enabled.
9. No database replication or HA configuration exists.
10. MySQL is bound specifically to `192.168.56.20:3306`.
11. The application database account is restricted to the application server and has limited data-access permissions.
12. Application-style database connections were verified to negotiate **TLS 1.3**.
13. TLS is not enforced globally because `require_secure_transport = OFF`.
14. No automated MySQL backup process has been technically verified.
15. Automatic Ubuntu updates can restart the database outside a controlled maintenance window.
16. The source database has availability, backup and recovery weaknesses that must be addressed in the AWS target design.

---

## 19. Discovery Status

**MySQL-specific technical discovery: COMPLETE**

### Outstanding items

- Verify whether customer-provided database backups exist.
- Validate backup restore capability if backups are supplied.
- Determine the final AWS database migration method during target architecture and migration planning.

---

## Evidence Handling

Passwords and credential values were intentionally excluded from this document.

Raw operating-system and infrastructure discovery evidence is stored separately in:

`onprem-db01-discovery-full.txt`

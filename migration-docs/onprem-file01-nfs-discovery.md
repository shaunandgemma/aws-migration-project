# ONPREM-FILE01 — NFS Technical Discovery

## Overview

| Item | Verified value |
|---|---|
| Server | `onprem-file01` |
| Purpose | Manual NFS/file-server technical discovery for the on-premises to AWS migration assessment |
| Operating system | Ubuntu 24.04.4 LTS |
| CPU | 2 vCPU |
| RAM | 1.9 GiB |
| Attached disk | 20 GB |
| Private IP | `192.168.56.30` |
| Root filesystem | 9.8 GB |
| Root filesystem utilisation | 49% |

> This document records verified technical findings only.

---

## 1. NFS Software

| Package | Version |
|---|---|
| `nfs-common` | `1:2.6.4-3ubuntu5.1` |
| `nfs-kernel-server` | `1:2.6.4-3ubuntu5.1` |
| `rpcbind` | `1.2.6-7ubuntu2` |

---

## 2. NFS Export

Exported directory:

`/srv/legacy-files`

Permitted client:

`192.168.56.10`

Configured export:

```text
/srv/legacy-files 192.168.56.10(rw,sync,no_subtree_check,all_squash)
```

### Verified active export options

- `rw`
- `sync`
- `wdelay`
- `hide`
- `no_subtree_check`
- `sec=sys`
- `secure`
- `root_squash`
- `all_squash`

---

## 3. Export Access Control

The NFS export is restricted to:

`192.168.56.10`

This is the private IP address of `onprem-app01`.

No additional NFS clients were configured in `/etc/exports`.

No additional export configuration files were identified under:

`/etc/exports.d`

---

## 4. Supported NFS Versions

Verified supported protocol versions:

- NFSv3
- NFSv4
- NFSv4.1
- NFSv4.2

---

## 5. Application Server NFS Mount

Verified from `onprem-app01`:

| Item | Value |
|---|---|
| Source | `192.168.56.30:/srv/legacy-files` |
| Mount point | `/mnt/legacy-files` |
| Filesystem type | `nfs4` |
| Protocol version | NFSv4.2 |
| Transport | TCP |
| Mount mode | Read/write |
| Security | `sec=sys` |
| Mount behaviour | `hard` |
| Read size | 262144 bytes |
| Write size | 262144 bytes |

---

## 6. Active Connection

An established NFS connection was observed between:

| Item | Value |
|---|---|
| Client | `192.168.56.10` |
| Server | `192.168.56.30` |
| Server port | `2049` |

This confirms that `onprem-app01` currently maintains an NFS connection to `onprem-file01`.

---

## 7. NFS Activity

NFS server RPC statistics showed:

| Metric | Value |
|---|---:|
| Total RPC calls | 136 |
| Bad calls | 0 |
| Bad format | 0 |
| Authentication failures | 0 |
| Bad client requests | 0 |

NFSv4 operations were observed.

This confirms that the NFS service has handled client activity.

---

## 8. Share Data Volume

Export path:

`/srv/legacy-files`

| Metric | Value |
|---|---:|
| Measured disk usage | 24 KB |
| Files | 4 |
| Directories | 2 |
| Symbolic links | 0 |
| Files with multiple hard links | None detected |

---

## 9. File Inventory

Files detected:

- `/srv/legacy-files/test.txt`
- `/srv/legacy-files/uploads/contract-001.txt`
- `/srv/legacy-files/uploads/report-001.txt`
- `/srv/legacy-files/uploads/invoice-001.txt`

All four files were identified as ASCII text files.

---

## 10. File Ownership and Permissions

### Files

| Item | Value |
|---|---|
| Owner | `nobody:nogroup` |
| Permissions | `-rw-r--r--` |

### Directories

| Item | Value |
|---|---|
| Owner | `nobody:nogroup` |
| Permissions | `drwxrwxr-x` |

This is consistent with the NFS export using `all_squash`.

---

## 11. File Timestamps

### Oldest discovered file

File:

`/srv/legacy-files/test.txt`

Modification time:

`2026-08-31 17:29`

### Newest discovered files

- `/srv/legacy-files/uploads/invoice-001.txt`
- `/srv/legacy-files/uploads/contract-001.txt`
- `/srv/legacy-files/uploads/report-001.txt`

Modification time:

Approximately `2026-08-31 18:03`

---

## 12. ACL and Extended Attribute Discovery

`getfacl` produced no recorded output.

`getfattr` produced no recorded output.

Because command errors were suppressed during discovery, this does not conclusively prove that ACLs or extended attributes are absent.

No ACL or extended-attribute dependency has currently been verified.

---

## 13. Active File Usage

`lsof` was executed against:

`/mnt/legacy-files`

No open files were returned at the time of discovery.

Verified finding:

No running process was observed with a file currently open from the NFS share.

> This does **not** prove that the application never uses the share. It only proves that no active file handle was detected during the discovery check.

---

## 14. Application Dependency Status

### Verified

- `onprem-app01` has `/srv/legacy-files` mounted.
- The mount is persistent.
- An active NFS network connection exists.
- The share is accessible from `onprem-app01`.

### Not yet technically verified

- The Flask application itself reads or writes files from `/mnt/legacy-files`.

Previous application-code discovery found no reference to:

`/mnt/legacy-files`

Therefore, the customer's statement that the application uses the file server remains an unverified application dependency.

---

## 15. Customer Data-Size Discrepancy

### Customer estimate

Approximately **2 GB** of shared files.

### Technical discovery

Approximately **24 KB** currently exists under:

`/srv/legacy-files`

This is a significant discrepancy.

Possible explanations could include:

- The customer estimate is outdated.
- Additional data exists elsewhere.
- The lab/source environment contains only representative data.

No conclusion should be assumed without further customer or technical evidence.

---

## 16. Backup Discovery

### Utility detected

- `/usr/bin/rsync`

### Not identified

- `rclone`
- `borg`
- `restic`
- `duplicity`

No dedicated file-share backup, snapshot, or `rsync` schedule was identified in the locations checked.

`dpkg-db-backup.timer` was detected.

> `dpkg-db-backup` is an Ubuntu package-management backup and is **not** a backup of `/srv/legacy-files`.

Verified finding:

No automated backup of the business file share has currently been technically verified.

---

## 17. Security

| Control | Finding |
|---|---|
| UFW | Inactive |
| nftables | No rules detected |
| iptables INPUT policy | ACCEPT |
| NFS export restriction | `192.168.56.10` only |
| NFS security mechanism | `sec=sys` |

NFS/RPC services are listening on multiple network interfaces.

However, the NFS export itself is restricted to `192.168.56.10`.

`sec=sys` relies on traditional Unix UID/GID-based authentication rather than Kerberos-based NFS security.

---

## 18. NFS Health

No NFS server errors or warnings were found in the reviewed `nfs-server`, `nfs-mountd`, or `rpcbind` journal entries.

No failed systemd units were detected.

A previous OS-level discovery recorded an NFS block-layout startup warning:

```text
open pipe file /run/rpc_pipefs/nfs/blocklayout failed
```

No evidence was found that this caused failure of the active NFS service.

---

## 19. Migration-Relevant Findings

1. The file server provides an NFS share from `/srv/legacy-files`.
2. The export is restricted to `onprem-app01`.
3. `onprem-app01` currently mounts the share using NFSv4.2.
4. An active NFS connection exists between the application and file servers.
5. Only 24 KB across 4 files is currently present.
6. This conflicts significantly with the customer's estimate of approximately 2 GB.
7. No symbolic-link or hard-link migration complexity was identified.
8. File ownership is simplified through `all_squash`.
9. No dedicated backup mechanism has been technically verified.
10. Host firewall filtering is not currently enabled.
11. NFS uses `sec=sys` rather than stronger identity-based authentication such as Kerberos.
12. The application server mount is verified, but direct use of the share by the Flask application remains unverified.
13. The AWS target must preserve required shared-file access only if the dependency is confirmed.
14. The final file migration design must account for permissions, ownership, application compatibility, backup requirements, and the customer's RPO/RTO targets.

---

## 20. Discovery Status

**NFS/file-server technical discovery: COMPLETE**

### Outstanding items

- Confirm whether the application genuinely reads/writes the NFS share.
- Resolve the 2 GB customer estimate versus 24 KB discovered.
- Verify whether customer file backups exist.
- Determine the final AWS file-storage target during architecture design.

---

## Evidence Handling

Raw operating-system and infrastructure discovery evidence is stored separately in:

`onprem-file01-discovery-full.txt`

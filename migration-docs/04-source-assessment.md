# Source Environment Assessment

## Purpose

This document assesses the customer requirements and verified technical discovery findings for the existing on-premises Customer Portal environment.

The purpose is to identify:

- Confirmed workloads and dependencies
- Business and technical requirements
- Availability and resilience gaps
- Backup and recovery gaps
- Security findings
- Operational risks
- Discovery discrepancies and unknowns
- Migration constraints
- Requirements that the AWS target design must address

No AWS target services are selected in this document. Architecture and service-selection decisions will be made after the source environment has been assessed.

---

## 1. Environment in Scope

The migration scope contains the following three on-premises servers:

| Server | Role | Private IP | Primary Function |
|---|---|---|---|
| `onprem-app01` | Application server | `192.168.56.10` | Hosts the Customer Portal using Nginx, Gunicorn and Flask |
| `onprem-db01` | Database server | `192.168.56.20` | Hosts the `legacy_app` MySQL database |
| `onprem-file01` | File server | `192.168.56.30` | Provides the `/srv/legacy-files` NFS share |

### Confirmed workload components

The in-scope workload consists of:

- Customer Portal application
- MySQL `legacy_app` database
- Shared NFS file storage
- Application configuration required to operate the portal
- Database and file data required by the workload

### Confirmed technical dependencies

The following dependency is technically verified:

`onprem-app01 -> onprem-db01`

The Flask application directly connects to MySQL over TCP port `3306`.

The following infrastructure relationship is also verified:

`onprem-app01 -> onprem-file01`

The application server mounts the NFS share over NFSv4.2. However, direct use of the share by the Flask application itself has not been technically verified.

### Out of scope at this stage

The following are not yet part of the AWS target design:

- Selection of AWS compute services
- Selection of AWS database services
- Selection of AWS shared-storage services
- Migration tooling
- Final network architecture
- Cutover implementation

These decisions will be made after the source assessment and migration strategy have been completed.

## 2. Business Requirements

- Business hours: Monday-Friday, 07:00-19:00
- Approximate users: 53
- Peak usage: 09:00-11:00 and 14:00-16:00
- Maximum acceptable downtime: 1 hour
- RTO: 1 hour
    - The Customer Portal service must be restored within 1 hour after a failure or recovery event
- RPO: 0
    - The customer expects zero data loss
- Maintenance windows should take place during evenings or weekends where possible
- More than 1 hour of downtime is considered critical
- Production changes require approval
- Testing should take place before production cutover
- Rollback must be available
- Final cutover requires customer approval
- Source systems should be retained until migration acceptance
- Avoid month-end cutover
- Migration success means:
    - The Customer Portal works correctly
    - Data remains intact
    - Required files are available
    - Performance is acceptable
    - Monitoring is in place
    - Backups are in place
    - Appropriate security controls are in place

## 3. Availability and Resilience Assessment

- The current environment has no redundancy across the application, database and file-server layers
- `onprem-app01` is a single application server.
- `onprem-db01` is a single MySQL database server with no replica or automatic failover.
- `onprem-file01` is a single NFS file server with no verified replica or failover.
- A failure of any required server could make part or all of the Customer Portal unavailable.
- This creates a risk against the customer's RTO of 1 hour.
- The current environment cannot guarantee the customer's 1-hour RTO.
- If `onprem-db01` fails, there is no standby database or automatic failover available.
- Recovery would depend on manual troubleshooting, repair, restore, or rebuild work.
- Because the recovery time is unpredictable, the Customer Portal could remain unavailable for longer than 1 hour.

## 4. Backup and Recovery Assessment

- No automated MySQL database backup process has been technically verified.
- No automated backup or snapshot process has been verified for `/srv/legacy-files`.
- The customer stated that monthly database backups may exist, but their location, retention and recoverability are unknown.
- Because backups have not been verified, the current environment cannot demonstrate that it can meet the customer's RPO of 0.

## 5. Security Assessment

- No effective host-level firewall filtering was identified on the source servers.
- UFW is inactive, no nftables rules were detected, and iptables policies default to ACCEPT.
- This increases the attack surface because network services may accept connections unless they are restricted elsewhere.
- The AWS target should apply stricter network access controls and least-privilege connectivity between application components.
- SSH is listening on all network interfaces and password authentication is enabled.
- This increases exposure because remote connection attempts can be made against the SSH service from any network that can reach those interfaces.
- Password-based authentication also increases the risk of brute-force or credential-based attacks compared with stronger key-based access controls.
- The AWS target should restrict administrative access and use stronger authentication methods.
- MySQL supports TLS, and the application connection was verified to use TLS 1.3.
- However, `require_secure_transport = OFF`, so encrypted transport is not enforced for every possible MySQL client.
- A client that is permitted to connect could potentially establish an unencrypted connection.
- This creates a risk that database traffic could be exposed in transit if a client connects without TLS.
- The NFS share uses `sec=sys`, which relies on client-provided Unix UID/GID information rather than strong identity-based authentication.
- This provides weaker assurance of user identity than Kerberos-based NFS security.
- The export is restricted to `192.168.56.10`, which reduces exposure, but the authentication model itself is still relatively weak.

- The application database account follows least-privilege principles.
- `legacy_app_user` is limited to SELECT, INSERT, UPDATE and DELETE permissions on the `legacy_app` database.
- The account is also restricted to connections originating from `192.168.56.10`.
- This reduces the impact if the application account is compromised because it does not have administrative database privileges.

## 6. Application Assessment

## 6. Application Assessment

- The application is small, using approximately 88 MB of disk space.
- The application architecture is simple and easy to understand.
- The application uses a single Flask application with a simple `/` route.
- Gunicorn runs the application locally on `127.0.0.1:5000`.
- Nginx provides the reverse-proxy layer in front of the application.
- The application has a clearly verified dependency on the MySQL database.
- Database credentials are not hard-coded in the application source code.
- The database password is supplied through an environment variable.
- No complex application components, background workers, or additional application services were identified.
- No direct application use of the NFS share has been technically verified.

## 7. Database Assessment

## 7. Database Assessment

- The `legacy_app` database is very small at approximately 0.05 MB.
- The schema is simple, with only two tables and one foreign-key relationship.
- No stored procedures, triggers or scheduled MySQL events were identified.
- Both tables use InnoDB.
- This low level of database complexity should make migration, validation and ongoing maintenance relatively straightforward.
- Binary logging is already enabled using ROW format with FULL row images, which is favourable for migration methods that use change-data capture.
- The main weaknesses are the lack of replication, automatic failover and a verified automated backup process.

## 8. File Storage Assessment

## 8. File Storage Assessment

- The file server provides an NFS share from `/srv/legacy-files`.
- `onprem-app01` mounts the share using NFSv4.2.
- Technical discovery found approximately 24 KB of data across 4 files.
- The customer estimated approximately 2 GB of shared-file data.
- This is a significant discovery discrepancy and must be resolved before the final file-migration method is selected.
- No automated backup or snapshot process for the file share has been technically verified.
- No replica or automatic failover mechanism was identified for the file server.
- Direct use of the NFS share by the Flask application has not been technically verified.

## 9. Network and Connectivity Assessment

## 9. Network and Connectivity Assessment

- The Customer Portal is intended to remain an internal-only service.
- The application, database and required file-storage components should not require direct public internet exposure.
- During migration, private connectivity will be required between the on-premises environment and the AWS environment.
- Remote users currently access the environment through the corporate network/VPN.
- The application requires connectivity to the database over TCP port 3306.
- The application server currently connects to the NFS file server over TCP port 2049.
- Network access between workload components should be restricted to only the ports and systems that require communication.
- No existing private connectivity between the customer environment and AWS has been identified.

## 10. Operational Assessment

## 10. Operational Assessment

- Ubuntu unattended upgrades can restart MySQL automatically.
- This can cause unexpected database downtime outside a planned maintenance window.
- Because the Customer Portal depends on MySQL, an automatic database restart can interrupt application availability.
- This creates an operational risk against the customer's 1-hour RTO.
- Database maintenance and patching should be controlled and scheduled rather than occurring unpredictably.

- Monitoring is largely manual, which increases operational effort and creates a risk that important issues may be missed.
- Logs are stored across individual systems rather than being viewed through a central monitoring and alerting platform.
- Centralised monitoring would make it easier to review logs, identify failures, and respond to important events from one place.
- Automated alerting would reduce the reliance on someone manually checking each server.

- Recovery is largely manual across the current environment.
- Because there is no redundancy or automatic failover, service restoration depends on manual troubleshooting, repair, rebuild or restore activity.
- This makes recovery time unpredictable and increases the risk of exceeding the customer's 1-hour RTO.

## 11. Discovery Discrepancies and Unknowns

## 11. Discovery Discrepancies and Unknowns

- The customer stated that the Customer Portal uses the file server.
- Technical discovery confirmed that `onprem-app01` mounts the NFS share, but no direct use of `/mnt/legacy-files` was found in the Flask application code.
- The file-server dependency therefore remains technically unverified at application level.

- The customer estimated approximately 2 GB of shared-file data.
- Technical discovery found approximately 24 KB under `/srv/legacy-files`.
- This discrepancy must be resolved before the final file-migration approach is selected.

- The customer stated that monthly database backups may exist.
- No automated MySQL backup process was technically verified.
- Backup location, retention, age and recoverability therefore remain unknown.

- No automated backup process for the NFS business files was technically verified.

- The exact final migration method for the database and file storage has not yet been selected.

## 12. Migration Constraints

## 12. Migration Constraints

- The customer's RPO of 0 means the migration must avoid any loss of customer or order data.
- The customer's RTO of 1 hour means the Customer Portal cannot remain unavailable for longer than 1 hour during recovery or cutover.
- The current source environment has no redundancy and no verified reliable backup process, which increases the risk if the migration fails.
- The migration therefore requires a controlled cutover, validation and rollback plan.
- Production changes require approval before implementation.
- Testing must be completed before production cutover.
- Cutover should take place during an evening or weekend maintenance window where possible.
- Month-end cutover should be avoided.
- The existing source environment must be retained until the customer accepts the migrated environment.
- Private connectivity between the source environment and AWS will be required during migration.

- The customer's RPO of 0 means the migration must avoid any loss of customer or order data.
- The customer's RTO of 1 hour means the Customer Portal cannot remain unavailable for longer than 1 hour during recovery or cutover.
- The current source environment has no redundancy and no verified reliable backup process, which increases the risk if the migration fails.
- The migration therefore requires a controlled cutover, validation and rollback plan.
- Production changes require approval before implementation.
- Testing must be completed before production cutover.
- Cutover should take place during an evening or weekend maintenance window where possible.
- Month-end cutover should be avoided.
- The existing source environment must be retained until the customer accepts the migrated environment.
- Private connectivity between the source environment and AWS will be required during migration.

## 13. Migration Risks

## 13. Migration Risks

- If users continue creating or modifying data on `onprem-db01` while the database is being migrated, the AWS target could become out of date.
- This could cause customer or order changes made during the migration window to be missing from the target database.
- Because the customer requires RPO 0, the migration method must keep source and target data synchronised until cutover or otherwise prevent writes during the final migration window.

- The customer estimated approximately 2 GB of shared-file data, while technical discovery found only 24 KB.
- If the discrepancy is not resolved before migration, required business files could be missed and left behind.
- The true file-storage scope must therefore be confirmed before the final file migration is performed.

- If the AWS application is cut over before its required backend dependencies are reachable, the Customer Portal may fail or become unusable.
- Loss of connectivity to the database would prevent the application from accessing required customer and order data.
- If the NFS share is confirmed as an application dependency, loss of file-storage connectivity could also prevent required file access.
- Database and file-storage connectivity must therefore be validated before production cutover.

- If a serious issue is discovered after cutover and no tested rollback plan exists, recovery time could increase significantly.
- The team may need to troubleshoot the new environment under pressure or rebuild parts of the migration.
- This increases the risk of exceeding the customer's 1-hour RTO.
- A tested rollback plan is therefore required before production cutover.

- If the source systems are decommissioned before the AWS environment has been fully validated and accepted, required application data, configuration or files could become unavailable.
- This could make recovery or rollback significantly harder if an issue is discovered after cutover.
- The source environment should therefore remain available until the migrated workload has been validated and formally accepted.

## 14. AWS Target Requirements

- The AWS target should remove the current single points of failure.
- The application layer should support redundancy and failover so that failure of a single application instance does not make the Customer Portal unavailable.
- The database layer should support automatic failover and improved resilience.
- If shared file storage is confirmed as a required application dependency, the file-storage layer should also provide resilient access without relying on a single server.
- The overall design should support the customer's 1-hour RTO.

- The AWS target should perform regular automated backups of critical database and file data.
- Backup retention should be defined and appropriate for the customer’s recovery requirements.
- Restore procedures should be tested so backups are proven to be usable.
- The design should minimise data loss and support the customer’s RPO of 0 as closely as technically achievable.

- The AWS target should provide centralised logging across the application, database, and supporting services.
- Monitoring should be automated rather than relying on manual checks.
- Alerts should notify the operations team when important failures, errors, or availability issues occur.
- Centralised observability should make it easier to investigate incidents and reduce the risk of problems being missed.

- The AWS target should enforce least-privilege network access between application components.
- Only required ports and traffic paths should be permitted between the application, database and file-storage layers.
- Administrative access should be restricted and protected with strong authentication.
- Security monitoring should be centralised so security findings can be reviewed from one place.
- Additional protections such as web application filtering or network firewalls should be considered only where the final architecture requires them.

- The AWS target should provide private connectivity between the on-premises environment and AWS during migration.
- The Customer Portal should remain an internal-only service and should not require direct public internet exposure.
- Remote users should continue to access the environment through controlled private network access.
- The final design should support secure connectivity between on-premises systems and AWS, for example through a VPN-based connection.

- Maintenance and patching should use controlled maintenance windows.
- Updates that could restart application or database services should be scheduled outside normal business hours where possible.
- The AWS target should avoid unexpected service restarts that could interrupt the Customer Portal.
- Maintenance processes should support the customer's availability requirements and 1-hour RTO.

- The migration process should support a tested rollback plan.
- The source environment should remain available until the AWS environment has been validated and accepted.
- Application and infrastructure changes should be version-controlled where practical.
- The team should be able to restore the previous working state if the cutover fails.
- Rollback steps should be documented and tested before production cutover.

- The AWS target should remain compatible with the application's required operating system, Python runtime, Flask, Gunicorn and Nginx components.
- The database target must be compatible with the existing MySQL schema, data types, authentication method and application connector.
- Application behaviour should remain consistent after migration.
- Compatibility should be validated in testing before production cutover.

- The AWS target should provide a non-production testing environment before production cutover.
- Application functionality, database connectivity, file access, security controls and monitoring should be tested before the live migration.
- Testing should confirm that the migrated environment behaves as expected without affecting the production source systems.
- Cutover should only proceed after testing has been completed successfully.

- The AWS target should be able to scale as the business and workload grow.
- The application layer should be able to increase capacity during periods of higher demand.
- Where appropriate, capacity should also be reduced during quieter periods to avoid paying for unnecessary resources.
- The design should support future growth without requiring major infrastructure redesign.

- The AWS target should provide clear visibility of cloud costs and resource usage.
- Budgets and spending thresholds should be defined.
- Automated alerts should notify the relevant team when costs approach or exceed agreed limits.
- Notifications should be delivered through suitable channels such as email or messaging.
- Resources should be reviewed regularly so unused or oversized services can be identified and reduced.

- Secrets and credentials should be stored in a central, secure location rather than hard-coded in application files.
- Stored secrets should be encrypted.
- Access to secrets should be restricted using least-privilege permissions.
- Applications should retrieve only the credentials they require.
- Secret access should be auditable so unauthorised or unexpected access can be investigated.

### AWS Target Requirements Summary

The AWS target should:

- Remove or reduce the current single points of failure.
- Support the customer's 1-hour RTO and zero-data-loss RPO requirement.
- Provide resilient application and database services with failover capability.
- Provide resilient shared storage if the NFS dependency is confirmed.
- Perform regular automated backups with tested restore procedures.
- Provide centralised logging, monitoring and automated alerting.
- Restrict network access using least-privilege security controls.
- Keep the Customer Portal private and support secure connectivity with the on-premises environment.
- Protect secrets and credentials through encrypted, centrally managed storage.
- Use controlled maintenance and patching windows.
- Support a tested rollback process during migration.
- Maintain compatibility with the existing application and MySQL workload.
- Provide a non-production environment for migration testing.
- Support scaling as workload demand changes.
- Provide cost visibility, budgets and automated cost alerts.

## 15. Source Assessment Status

## 15. Source Assessment Status

**Source assessment status: COMPLETE**

The customer requirements and verified technical discovery findings have now been assessed across:

- Application
- Database
- File storage
- Networking
- Availability and resilience
- Backup and recovery
- Security
- Operations
- Migration constraints
- Migration risks
- AWS target requirements

### Outstanding items

The following items remain unresolved and must be tracked during later migration planning:

- Confirm whether the Flask application genuinely requires the NFS file share.
- Resolve the customer estimate of approximately 2 GB of shared files versus the 24 KB technically discovered.
- Verify whether any usable customer database backups exist.
- Verify whether any usable file-share backups exist.
- Determine the final migration methods for the application, database and file data.
- Determine the final AWS architecture and services.

The source environment has now been sufficiently assessed to begin migration strategy and AWS target architecture planning.
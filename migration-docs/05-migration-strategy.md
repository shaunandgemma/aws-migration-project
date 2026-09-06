## 1. Migration Approach

The migration will use a mixed Rehost and Replatform strategy.

### Application Server

`onprem-app01` will use a Rehost approach.

The existing Nginx, Gunicorn, Flask and Python application stack will be moved to AWS with minimal application changes.

### Database Server

`onprem-db01` will use a Replatform approach.

The existing MySQL `legacy_app` database will be migrated from the self-managed MySQL server to Amazon RDS for MySQL.

This removes the need to operate the MySQL database directly on a virtual machine while keeping the application database engine compatible with the existing workload.

### File Server

`onprem-file01` will initially use a Rehost approach unless the unresolved file-server dependency changes the migration scope.

The existing NFS-based file-storage behaviour will be preserved with minimal change.

### Scope

The objective is to minimise application changes while moving the workload into AWS and replacing the self-managed MySQL database with Amazon RDS for MySQL.

Application refactoring is outside the scope of this migration.

## 2. Application Server Migration Strategy

`onprem-app01` will use a Rehost migration approach.

The existing application server will be replicated into AWS and launched as an Amazon EC2 instance rather than being manually rebuilt.

The objective is to preserve the existing:

- Ubuntu operating system
- Nginx configuration
- Gunicorn configuration
- Flask application
- Python environment and dependencies
- systemd application service
- Application files and server configuration

A replication-based migration approach will be used so the existing server can be tested in AWS before production cutover.

Some configuration changes will still be required after migration, including:

- Updating the application database connection from the existing MySQL server to the new Amazon RDS endpoint
- Updating any confirmed file-storage dependencies
- Applying the required AWS network and security configuration
- Validating application functionality before cutover

The existing source application server will remain available until the AWS instance has been tested and the migration has been accepted.

## 3. Database Migration Strategy

`onprem-db01` will use a Replatform migration approach.

The existing `legacy_app` MySQL database will be migrated from the self-managed MySQL server to Amazon RDS for MySQL.

AWS Database Migration Service will be used with:

- Initial full-load migration
- Ongoing Change Data Capture (CDC)

The initial full load will copy the existing database into Amazon RDS.

CDC will then replicate ongoing INSERT, UPDATE and DELETE activity from the source MySQL binary logs into the RDS target while the source application remains operational.

Technical discovery confirmed that the source MySQL server already has:

- Binary logging enabled
- ROW binlog format
- FULL binlog row image
- 30-day binary-log retention

These settings are favourable for CDC-based migration.

### Cutover Approach

During the final migration window:

1. Stop or prevent new application database writes.
2. Allow AWS DMS to apply any remaining source changes.
3. Confirm replication lag has reached zero.
4. Validate the source and target data.
5. Update the application database connection to the Amazon RDS endpoint.
6. Test application functionality.
7. Re-enable user access after successful validation.

This approach is intended to minimise downtime and reduce the risk of data loss during cutover.

The source MySQL server will remain available until the RDS migration has been validated and accepted.

## 4. File Server Migration Strategy

`onprem-file01` will use a Rehost migration approach.

The existing file server will be replicated into AWS and launched as an Amazon EC2 instance rather than being redesigned around a different storage service.

The objective is to preserve the existing:

- Ubuntu operating system
- NFS server configuration
- `/etc/exports`
- `/srv/legacy-files`
- File ownership and permissions
- Existing NFS behaviour

A replication-based migration approach will be used so the server can be tested in AWS before production cutover.

### Outstanding File-Storage Issue

The customer estimated approximately 2 GB of shared-file data, while technical discovery found only approximately 24 KB.

The true file-storage scope must therefore be confirmed before final cutover.

The Flask application's direct use of the NFS share has also not been technically verified.

### Cutover Considerations

Before production cutover:

1. Confirm the complete file dataset that must be migrated.
2. Verify the replicated AWS file server contains the required files.
3. Verify file ownership and permissions.
4. Confirm NFS access from the migrated application server.
5. Update the application server's NFS mount configuration if the AWS file-server address changes.
6. Validate required file access before allowing production use.

The source file server will remain available until the AWS environment has been validated and accepted.

## 5. Migration Order and Waves

The migration will be performed in a controlled sequence so that required dependencies are available before the Customer Portal is cut over.

### Wave 1 — Network and Connectivity Preparation

Prepare the AWS network environment and private connectivity required between the on-premises environment and AWS.

This connectivity is required so that:

- AWS migration services can communicate with the source environment
- The source database can replicate to AWS
- Test instances can communicate with required dependencies
- Migration validation can be performed before cutover

### Wave 2 — Database Target Preparation

Prepare the Amazon RDS for MySQL target environment.

The RDS database must be available before database migration can begin.

### Wave 3 — Database Migration

Start the AWS DMS migration using:

- Initial full load
- Ongoing Change Data Capture (CDC)

The source application will continue using `onprem-db01` while DMS keeps the RDS target synchronised with ongoing database changes.

### Wave 4 — File Server Migration

Replicate `onprem-file01` into AWS and launch a test EC2 instance.

Validate:

- NFS service operation
- Required files
- File ownership and permissions
- Network access from the migrated application environment

The unresolved file-size and application-dependency findings must be addressed before final cutover.

### Wave 5 — Application Server Migration

Replicate `onprem-app01` into AWS and launch a test EC2 instance.

Validate:

- Operating system
- Nginx
- Gunicorn
- Flask application
- Application configuration
- Database connectivity
- Required file-storage connectivity

### Wave 6 — Integration Testing

Test the complete AWS workload before production cutover.

This includes:

- Application functionality
- Application-to-RDS connectivity
- Application-to-file-server connectivity if required
- Database data validation
- File validation
- Security controls
- Logging and monitoring
- Recovery and rollback procedures

### Wave 7 — Production Cutover

During the approved maintenance window:

1. Stop or prevent new application database writes.
2. Allow AWS DMS to apply all remaining database changes.
3. Confirm replication lag has reached zero.
4. Validate source and RDS data.
5. Update the migrated application to use the RDS endpoint.
6. Confirm required NFS connectivity.
7. Perform application validation.
8. Re-enable user access after successful testing.

### Wave 8 — Post-Cutover Validation

After cutover:

- Monitor application health
- Monitor database connectivity
- Confirm expected customer and order data
- Confirm required file access
- Review logs and alerts
- Confirm performance is acceptable
- Obtain customer acceptance

The original source servers will remain available until the migrated environment has been validated and accepted.

## 6. Migration Connectivity Strategy

Private connectivity will be established between the on-premises environment and AWS before workload migration begins.

AWS Site-to-Site VPN will be used to provide encrypted connectivity between the source network and the AWS VPC.

This connectivity will support:

- AWS DMS communication with `onprem-db01`
- Testing of migrated application and file-server instances
- Access between source and AWS environments during migration
- Validation before production cutover

The source database and file services will not be exposed directly to the public internet for migration purposes.

Network access will be restricted so that only required systems and ports can communicate.

Required migration traffic includes:

- MySQL: TCP 3306
- NFS: TCP 2049, if the file dependency is required
- Administrative access only where necessary

The VPN will remain available throughout migration, testing and cutover until the source environment is no longer required.

## 7. Pre-Cutover Testing Strategy

The AWS environment will be tested before production cutover while the original on-premises environment remains operational.

This allows migration issues to be identified and corrected without affecting live users.

Testing will include:

- Confirming the migrated EC2 application server starts successfully
- Verifying Nginx is running
- Verifying Gunicorn is running
- Verifying the Flask application loads successfully
- Confirming the application can connect to Amazon RDS for MySQL
- Comparing migrated database records with the source database
- Verifying required NFS connectivity if the file-server dependency is confirmed
- Confirming required files are present and accessible
- Testing network access restrictions
- Verifying logging and monitoring
- Verifying alerting
- Checking application performance
- Testing the rollback procedure

### Application Baseline

The source Customer Portal returned:

- HTTP status: `200 OK`
- Customer count: `53`

This baseline will be compared with the migrated AWS environment during testing.

The expected customer count must take into account any legitimate database changes that occur after the original baseline was recorded.

### Testing Principle

The AWS environment should be tested while the original on-premises environment remains operational.

This allows configuration errors, connectivity issues, application failures and data problems to be identified before production cutover.

Problems can be corrected without affecting live users.

Keeping the source environment available also preserves a rollback option if testing fails.

Production cutover will only proceed after the required tests have completed successfully.

## 8. Cutover Strategy

The production cutover will be performed during an approved maintenance window.

The objective is to minimise downtime and avoid data loss while switching the Customer Portal from the on-premises environment to AWS.

### Cutover Steps

1. Notify users that the maintenance window has started.
2. Stop or prevent new application database writes.
3. Confirm the source application is no longer changing production data.
4. Allow AWS DMS to apply any remaining database changes to Amazon RDS.
5. Confirm DMS replication lag has reached zero.
6. Compare source and target database data.
7. Confirm required customer and order records are present.
8. Update the migrated application configuration to use the Amazon RDS endpoint.
9. Confirm required NFS connectivity if the file-server dependency is confirmed.
10. Start or restart the migrated application services if required.
11. Test the Customer Portal.
12. Confirm HTTP responses are successful.
13. Confirm application-to-database connectivity.
14. Confirm required file access.
15. Review logs and monitoring for errors.
16. Re-enable user access after successful validation.

### Data Protection During Cutover

New application writes will be stopped immediately before final cutover.

This prevents the source database from continuing to change while AWS DMS applies the remaining transactions.

DMS will then be allowed to catch up until replication lag reaches zero.

This helps ensure that Amazon RDS contains all committed source changes before users are switched to the AWS environment.

### Cutover Success Criteria

Cutover will be considered successful when:

- The Customer Portal is accessible.
- The application returns successful HTTP responses.
- The application can connect to Amazon RDS.
- Source and target database data has been validated.
- Required files are accessible.
- No critical application errors are present.
- Monitoring and alerting are functioning.
- Application performance is acceptable.
- The customer approves the migrated environment.

If these checks fail, the rollback procedure will be initiated.

## 9. Rollback Strategy

A rollback plan will be maintained until the AWS environment has been fully validated and accepted by the customer.

The original on-premises environment will remain available during migration and cutover so that it can be used as the fallback environment if the AWS cutover fails.

### Rollback Conditions

Rollback should be considered if:

- The Customer Portal is unavailable after cutover
- The application cannot connect to Amazon RDS
- Required database records are missing or inconsistent
- Required file access fails
- Critical application errors are detected
- Performance is unacceptable
- Security or network issues prevent normal operation
- Cutover is at risk of exceeding the approved maintenance window

### Rollback Steps

1. Stop or prevent user access to the AWS application.
2. Stop any new production writes to the AWS environment.
3. Confirm the original on-premises application and database remain healthy.
4. Restore user access to the on-premises Customer Portal.
5. Confirm the application can connect to `onprem-db01`.
6. Confirm required file access from `onprem-file01`.
7. Validate application functionality.
8. Notify the customer that service has been restored to the source environment.
9. Investigate and correct the AWS migration issue before attempting another cutover.

### Data Consistency

The source database will remain the authoritative production database until the AWS cutover has been successfully validated.

Users will not be allowed to create new production data in AWS until cutover validation has completed successfully.

This reduces the risk of data being created in AWS that does not exist in the source environment if rollback becomes necessary.

### Source Retention

The source application, database and file servers will not be decommissioned until:

- The AWS environment has passed validation
- The customer has formally accepted the migrated workload
- Required rollback capability is no longer needed

## 10. Post-Cutover Validation Strategy

Post-cutover validation will be performed immediately after the Customer Portal is switched to the AWS environment.

The purpose is to confirm that the production workload continues to operate correctly under real user traffic and final production configuration.

### Validation Checks

Post-cutover validation will include:

- Confirming the Customer Portal is accessible
- Confirming successful HTTP responses
- Verifying Nginx, Gunicorn and Flask application services are healthy
- Confirming the application can connect to Amazon RDS
- Verifying current customer and order data
- Comparing important source and target database records
- Confirming required NFS/file access if the dependency is confirmed
- Reviewing application and system logs
- Confirming monitoring and alerting are working
- Checking application response times and general performance
- Confirming no critical security or network issues are present

### Production Validation

Post-cutover validation is required because the live production environment may behave differently from the pre-cutover test environment.

Real users, production traffic, final configuration and live data can expose issues that were not identified during testing.

### Customer Acceptance

The migrated workload will remain under increased observation after cutover.

The customer will be asked to confirm that:

- The Customer Portal works as expected
- Required data is present
- Required files are available
- Performance is acceptable
- No business-critical issues remain

The source environment will remain available until production validation is complete and the customer has formally accepted the AWS environment.

## 11. Decommissioning Strategy

The original on-premises environment will remain available after AWS cutover until the migrated workload has completed production validation and the customer has formally accepted the AWS environment.

### Decommissioning Conditions

The source servers should only be decommissioned after:

- Production validation has completed successfully
- The customer has accepted the AWS environment
- Rollback is no longer required
- Required database and file data has been verified in AWS
- Any required backups have been taken
- Required configuration, logs and migration evidence have been retained
- No remaining application dependency points to the source environment
- AWS DMS replication is no longer required

### Source Systems

The following systems will be retained until the above conditions are met:

- `onprem-app01`
- `onprem-db01`
- `onprem-file01`

### Decommissioning Risk

The source environment should not be decommissioned immediately after AWS cutover.

Keeping `onprem-app01`, `onprem-db01` and `onprem-file01` available preserves a fallback option if an issue appears after migration.

Decommissioning should only happen after production validation is complete, the customer has accepted the AWS environment, and rollback is no longer required.

### Final Decommissioning Actions

Once approval has been received:

1. Confirm the AWS environment is stable.
2. Confirm no production traffic is using the source systems.
3. Confirm required backups and migration evidence have been retained.
4. Stop any remaining replication processes.
5. Shut down the source servers.
6. Retain the source systems for any agreed retention period if required.
7. Remove the source systems only after final approval.

## 12. Migration Strategy Status

**Migration strategy status: COMPLETE**

The migration strategy has now been defined for:

- Application server migration
- Database migration
- File server migration
- Migration order and waves
- Private connectivity
- Pre-cutover testing
- Production cutover
- Rollback
- Post-cutover validation
- Source-system decommissioning

### Agreed Migration Approaches

- `onprem-app01`
  - Rehost
  - Replicate into Amazon EC2

- `onprem-db01`
  - Replatform
  - Migrate MySQL to Amazon RDS for MySQL
  - Use AWS DMS full load plus Change Data Capture

- `onprem-file01`
  - Rehost
  - Replicate into Amazon EC2

### Resolved Items

The following previously outstanding items have now been resolved:

- NFS file-share dependency
  - The existing NFS configuration will be retained as part of the migration.
  - `onprem-file01` will remain in scope and will be rehosted without changing the existing file-storage behaviour.

- Shared-file data volume
  - The customer confirmed that the earlier estimate of approximately 2 GB was incorrect.
  - The technically discovered data volume of approximately 24 KB is the correct migration scope.

- Source database backups
  - The customer confirmed that no usable source database backups exist.

- Source file-server backups
  - The customer confirmed that no usable source file backups exist.

### Outstanding Design Items

The following items will now be resolved during AWS Target Architecture and Detailed Design:

- Finalise AWS network design and addressing
- Finalise Amazon RDS configuration
- Finalise EC2 sizing and configuration
- Finalise AWS DMS configuration
- Define monitoring, logging, backup and security controls
- Confirm the final maintenance window and customer approval process

The migration strategy is sufficiently defined to move into the next phase:

**AWS Target Architecture and Detailed Design**
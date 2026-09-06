# AWS Target Architecture and Detailed Design

## Purpose

This document defines the planned AWS target architecture for the Customer Portal migration.

The design is based on the completed customer discovery, technical discovery, source assessment, and migration strategy.

The target architecture is intended to:

- Keep the Customer Portal internal-only
- Improve resilience compared with the existing on-premises environment
- Support the customer's 1-hour RTO
- Protect data at rest and in transit
- Provide controlled private connectivity during migration
- Support database migration using AWS DMS
- Provide backup and recovery capability
- Allow the temporary lab environment to be torn down cleanly after validation

---

## 1. AWS Region

The target AWS Region will be:

`eu-west-2` — London

### Reasoning

- The business and its users are located in the UK.
- No users have been identified outside the UK.
- Hosting the workload in the London Region should provide lower latency for users and for connectivity back to the on-premises environment.
- Using a UK Region keeps the workload geographically close to the customer.
- The required AWS services for this migration are available in `eu-west-2`.

---

## 2. Availability Zone Strategy

The AWS target environment will use multiple Availability Zones within the `eu-west-2` London Region.

The initial design will use:

- `eu-west-2a`
- `eu-west-2b`

### Reasoning

- The customer has a 1-hour RTO requirement.
- The existing environment has several single points of failure.
- Using multiple Availability Zones provides the foundation for improved resilience.
- Critical AWS services can be distributed across separate Availability Zones so that failure of a single AZ does not affect the entire target environment.
- Amazon RDS can use a Multi-AZ configuration to provide database failover capability.

Using multiple Availability Zones does not automatically make individual EC2 workloads highly available. Application and file-server resilience must be designed separately.

---

## 3. VPC and Subnet Strategy

The AWS workload will be deployed inside a dedicated VPC in `eu-west-2`.

The application, database, and file-server workloads will be placed in private subnets.

### Reasoning

- The Customer Portal is an internal-only service.
- The application server does not require direct public internet exposure.
- Amazon RDS should not be publicly accessible.
- The rehosted NFS file server should remain private.
- Communication between application components should remain inside the VPC wherever possible.
- Access from the customer environment will be provided through private connectivity.

### VPC CIDR

The VPC will use:

`10.20.0.0/16`

Existing on-premises network:

`192.168.56.0/24`

The AWS VPC uses a non-overlapping CIDR range so that routing between the on-premises network and AWS can operate correctly.

The `/16` VPC range also leaves substantial address space available for future subnets and workload growth.

### Subnet Layout

Separate private subnet tiers will be created for application and database resources across both Availability Zones.

| Subnet | Availability Zone | CIDR | Purpose |
|---|---|---|---|
| `app-private-a` | `eu-west-2a` | `10.20.1.0/24` | Application and private compute |
| `app-private-b` | `eu-west-2b` | `10.20.2.0/24` | Application and private compute |
| `db-private-a` | `eu-west-2a` | `10.20.3.0/24` | Amazon RDS |
| `db-private-b` | `eu-west-2b` | `10.20.4.0/24` | Amazon RDS |

```text
VPC 10.20.0.0/16
│
├── eu-west-2a
│   ├── App Private 10.20.1.0/24
│   └── DB Private  10.20.3.0/24
│
└── eu-west-2b
    ├── App Private 10.20.2.0/24
    └── DB Private  10.20.4.0/24
```


### Regional NAT Gateway Strategy

A single Regional NAT Gateway will provide outbound internet access for private application and file-server workloads without requiring dedicated public subnets.

The Regional NAT Gateway will operate across both Availability Zones used by the workload:

- `eu-west-2a`
- `eu-west-2b`

### Reasoning

- Application and file-server EC2 instances remain in private subnets.
- Private instances require outbound internet access for operating-system updates, package repositories and required external services.
- Regional NAT Gateway automatically provides NAT capability across the Availability Zones containing the workload.
- A separate zonal NAT Gateway does not need to be deployed in each Availability Zone.
- Dedicated public subnets are not required to host the Regional NAT Gateway.
- This simplifies routing while maintaining multi-AZ NAT availability.
- The NAT Gateway remains one of the larger fixed networking costs in the architecture.

---

## 4. Route Table Strategy

No public subnet route table is required solely for Regional NAT Gateway placement.


### Application Private Route Table A

Associated subnet:

- `app-private-a`

Routes:

- `10.20.0.0/16` → local
- `0.0.0.0/0` → Regional NAT Gateway
- `192.168.56.0/24` → Site-to-Site VPN

### Application Private Route Table B

Associated subnet:

- `app-private-b`

Routes:

- `10.20.0.0/16` → local
- `0.0.0.0/0` → Regional NAT Gateway
- `192.168.56.0/24` → Site-to-Site VPN

### Database Private Route Table

Associated subnets:

- `db-private-a`
- `db-private-b`

The database subnets will initially use VPC-local routing only.

No general internet route will be provided to the database subnets.

Additional private routes will only be added if required by the final migration design.

---

## 5. Site-to-Site VPN Strategy

The migration will use AWS Site-to-Site VPN to provide private connectivity between the on-premises environment and the AWS VPC.

### AWS VPN Components

The AWS side will use a Virtual Private Gateway (VGW) attached to the migration VPC.

The customer side will be represented by a Customer Gateway.

### Network Ranges

On-premises network:

`192.168.56.0/24`

AWS VPC:

`10.20.0.0/16`

These ranges do not overlap.

### Reasoning

- Only one VPC currently requires connectivity.
- A Virtual Private Gateway is simpler than introducing AWS Transit Gateway.
- The VPN provides encrypted connectivity between the customer environment and AWS.
- Migration traffic such as AWS DMS replication can use the private VPN connection.
- The source database and file-server services do not need to be exposed publicly.

### Routing

Application private subnets that require on-premises access will include a route for:

`192.168.56.0/24`

through the VPN.

Only required systems and ports will be permitted across the connection.

---

## 6. Application EC2 Design

The application layer will use Amazon EC2 instances deployed across two Availability Zones.

### Instance Configuration

Initial instance type:

`t3.small`

Initial capacity:

- 1 instance in `app-private-a`
- 1 instance in `app-private-b`

### Reasoning

- The existing application server uses 2 vCPU and approximately 1.9 GiB RAM.
- The Flask application is lightweight and currently serves a relatively small user base.
- `t3.small` provides sufficient initial capacity without unnecessarily oversizing the workload.
- Using two instances across separate Availability Zones improves resilience compared with the current single application server.
- Capacity can be increased later if monitoring shows that additional resources are required.

### Resilience

The application instances will be placed behind an internal Application Load Balancer.

An Auto Scaling Group will maintain the required application capacity across both Availability Zones.

This removes the current application-server single point of failure while preserving the existing Nginx, Gunicorn, and Flask application stack.

### Application Server Storage

Each application EC2 instance will use:

`20 GiB gp3`

The EBS volumes will be encrypted at rest using an AWS-managed KMS key.

### Storage Reasoning

- The source application server currently uses a 20 GB virtual disk.
- The application itself uses approximately 88 MB.
- 20 GiB provides sufficient capacity for the operating system, application files, logs, and future growth.
- gp3 provides suitable general-purpose storage for this lightweight workload.
- Encryption at rest protects application and system data stored on the EBS volumes.

### Application Server Backup Strategy

The application EC2 instances will be protected using AWS Backup.

Initial backup retention:

`7 days`

### Backup Reasoning

- The application servers contain operating-system configuration, Nginx, Gunicorn, Flask application files, and systemd configuration.
- Automated backups provide an additional recovery option if an instance or volume is damaged or misconfigured.
- AWS Backup provides centralised backup scheduling, retention, and recovery management.
- A 7-day retention period is sufficient for this temporary migration lab.
- The application can also be recreated through the Auto Scaling Group and replicated server image, but backups provide another recovery layer.
- Restore capability should be tested to confirm that backups are usable.

---

## 7. Internal Application Load Balancer Design

The Customer Portal will use an internal Application Load Balancer.

The ALB will span both application subnets:

- `app-private-a`
- `app-private-b`

### Listener

The ALB will use:

`HTTPS :443`

### Reasoning

- The Customer Portal is an internal-only service and does not require an internet-facing load balancer.
- HTTPS provides encryption in transit between users and the Application Load Balancer.
- The Site-to-Site VPN also encrypts traffic between the customer network and AWS, providing an additional network-level protection layer.
- TLS will terminate at the ALB.
- The ALB will forward traffic to the application instances over HTTP on TCP port 80.
- The existing Nginx configuration can therefore remain largely unchanged.

### Target Group

The ALB target group will contain the application EC2 instances running in:

- `eu-west-2a`
- `eu-west-2b`

The load balancer will distribute requests across both instances and remove unhealthy instances from service when health checks fail.

---

## 8. Application Health Checks and Auto Scaling

### ALB Health Check

The Application Load Balancer will initially use:

`/`

as the application health-check path.

The health check will verify the complete application path, including:

- Nginx
- Gunicorn
- Flask
- Database connectivity

A successful response will return HTTP `200`.

### Auto Scaling Group

Initial Auto Scaling configuration:

- Minimum capacity: 2
- Desired capacity: 2
- Maximum capacity: 4

The Auto Scaling Group will span:

- `app-private-a`
- `app-private-b`

### Reasoning

- Two instances provide resilience across both Availability Zones.
- The Auto Scaling Group can replace unhealthy EC2 instances automatically.
- Capacity can increase if workload demand grows.
- The application is currently lightweight, so a maximum of four instances provides reasonable headroom without unnecessary overprovisioning.

---

## 9. Amazon RDS for MySQL Design

Amazon RDS for MySQL will be deployed using a Multi-AZ configuration.

### Placement

The RDS deployment will use the dedicated database subnets:

- `db-private-a`
- `db-private-b`

The database will not be publicly accessible.

### Multi-AZ Reasoning

- The customer has a 1-hour RTO requirement.
- The current source database is a single point of failure.
- Multi-AZ provides a standby database in a separate Availability Zone.
- If the primary database instance fails, Amazon RDS can automatically fail over to the standby.
- This improves database resilience without requiring the customer to manage MySQL replication manually.

### RDS Instance Sizing

Initial DB instance class:

`db.t3.micro`

### Sizing Reasoning

- The `legacy_app` database is approximately 0.05 MB.
- Current workload activity is light.
- The source database uses 2 vCPU and approximately 1.9 GiB RAM, but the actual database workload does not justify matching that capacity directly.
- `db.t3.micro` provides a cost-effective starting point for the migrated workload.
- Database performance will be monitored after migration and the instance class can be increased if required.

### RDS Storage

Initial storage allocation:

`20 GiB gp3`

### Storage Reasoning

- The current `legacy_app` database is approximately 0.05 MB.
- 20 GiB provides substantial headroom for future growth.
- gp3 provides a cost-effective general-purpose storage option.
- The initial allocation avoids overprovisioning while still providing a practical production starting point.
- Storage growth can be monitored and adjusted if required.

### RDS Backup Retention

Automated backup retention:

`7 days`

### Backup Reasoning

- The customer requires reliable recovery capability.
- The source environment has no verified usable database backups.
- Amazon RDS automated backups will provide recovery points and point-in-time recovery capability.
- A 7-day retention period is sufficient for this temporary migration lab while still demonstrating a realistic backup strategy.
- In a production engagement, the final retention period would be agreed with the customer based on business, compliance, and recovery requirements.

### RDS Encryption at Rest

Amazon RDS storage will be encrypted using the AWS-managed KMS key for RDS.

### Encryption Reasoning

- The database contains customer names, email addresses, and order information.
- Encryption at rest protects the underlying RDS storage and automated backups.
- The AWS-managed KMS key provides encryption without adding the management overhead of a customer-managed key.
- This is appropriate for the temporary migration lab.
- In a production engagement, a customer-managed KMS key could be considered if stricter key-control or compliance requirements existed.

### Database Credentials and Secrets

Amazon RDS credentials will be stored in AWS Secrets Manager.

### Secrets Reasoning

- Database credentials should not be hard-coded in application files.
- Secrets Manager provides a central location for storing sensitive credentials.
- Secrets are encrypted at rest.
- Access can be restricted using IAM permissions.
- The application can retrieve only the secret it requires.
- Secret access can be audited.
- This is more secure and easier to manage than storing the password permanently in `/etc/legacy-app.env`.

---

## 10. Security Group Design

Separate Security Groups will be used for each workload tier.

### Internal ALB Security Group

Inbound:

- TCP 443 from the approved on-premises/corporate network

Outbound:

- TCP 80 to the application Security Group

### Application EC2 Security Group

Inbound:

- TCP 80 from the ALB Security Group
- TCP 22 from the approved on-premises administrative network over the Site-to-Site VPN

Outbound:

- TCP 3306 to the RDS Security Group
- TCP 2049 to the file-server Security Group
- Required outbound traffic for operating-system updates and package downloads; private-subnet routing will send internet-bound traffic through the NAT Gateway

### Amazon RDS Security Group

Inbound:

- TCP 3306 from the application Security Group
- TCP 3306 from the AWS DMS replication resources during migration

The database will not accept general VPC or public access.

### File Server Security Group

Inbound:

- TCP 2049 from the application Security Group
- TCP 22 from the approved on-premises administrative network over the Site-to-Site VPN

### Administrative Access

SSH administration will be performed through the Site-to-Site VPN.

No EC2 instance will require a public IP address for SSH access.

### Reasoning

- Network access is restricted to required communication paths.
- Security Group references are used between AWS workload components where possible.
- Administrative SSH traffic remains private through the VPN.
- RDS is accessible only from the application tier and migration components that require database connectivity.
- The design avoids exposing EC2 or RDS directly to the public internet.

```text
Corporate network
192.168.56.0/24
       |
     HTTPS 443
       v
   Internal ALB
   [alb-sg]
       |
     HTTP 80
       v
 Application EC2
    [app-sg]
     /      \
  3306      2049
   |          |
   v          v
  RDS      File EC2
[db-sg]    [file-sg]
```

---

## 11. File Server EC2 Design

`onprem-file01` will be rehosted as an Amazon EC2 instance.

### Instance Configuration

Initial instance type:

`t3.small`

Placement:

- Private application/compute subnet
- No public IP address

### Reasoning

- The source file server uses 2 vCPU and approximately 1.9 GiB RAM.
- The discovered NFS workload is very light.
- `t3.small` closely matches the existing compute and memory requirements.
- Rehosting preserves the existing Ubuntu and NFS configuration with minimal architectural change.

### NFS Configuration

The migrated server will retain:

- `/srv/legacy-files`
- NFS server configuration
- Existing file ownership and permissions
- NFSv4 compatibility
- Existing shared-file behaviour

Application instances will access the migrated file server over TCP port `2049`.

### Availability Consideration

The file server will initially remain a single EC2 instance because the agreed migration approach is Rehost.

This means the file-storage layer will continue to represent a single point of failure.

Improving file-storage resilience through a managed or distributed storage service can be considered as a post-migration modernisation activity.

### File Server Storage

Initial EBS storage:

`20 GiB gp3`

### Storage Reasoning

- The source file server currently uses a 20 GB virtual disk.
- The discovered business-file dataset is approximately 24 KB.
- 20 GiB provides substantial capacity above the current requirement.
- gp3 provides suitable general-purpose storage for the lightweight NFS workload.
- Storage capacity can be increased later if file usage grows.

### File Server EBS Encryption

The file-server EBS volume will be encrypted at rest using an AWS-managed KMS key.

### Encryption Reasoning

- The file server may contain customer or business data.
- Encryption protects the EBS volume and associated snapshots at rest.
- The AWS-managed key provides encryption without adding unnecessary key-management overhead for this temporary migration lab.
- In a production environment, a customer-managed KMS key could be considered if stricter key-control or compliance requirements existed.

### File Server Backup Strategy

The migrated file server will use AWS Backup to create automated backups of the EBS volume.

Initial backup retention:

`7 days`

### Backup Reasoning

- The source file server currently has no verified usable backup.
- Automated backups reduce reliance on manual snapshot creation.
- EBS backups provide a recovery point if the migrated file server or its data is damaged.
- AWS Backup provides centralised backup scheduling, retention, and recovery management.
- A 7-day retention period is appropriate for this temporary migration lab.
- In a production environment, backup frequency and retention would be agreed with the customer based on business and compliance requirements.
- Restore capability should be tested to confirm that the backups are usable.

---

## 12. AWS DMS Design

AWS Database Migration Service will migrate the `legacy_app` database from the on-premises MySQL server to Amazon RDS for MySQL.

### Replication Instance

Lab replication instance class:

`dms.t3.micro`

### Placement

The DMS replication subnet group will use:

- `app-private-a`
- `app-private-b`

The DMS replication instance will remain private and will not require a public IP address.

### Source Endpoint

Source database:

- Server: `onprem-db01`
- IP: `192.168.56.20`
- Engine: MySQL
- Port: TCP `3306`
- Database: `legacy_app`

AWS DMS will reach the source database through the Site-to-Site VPN.

### Target Endpoint

Target database:

- Amazon RDS for MySQL
- Private RDS endpoint
- Port: TCP `3306`

DMS will communicate with RDS through private VPC connectivity.

### Migration Task

The DMS migration task will use:

- Full load
- Ongoing Change Data Capture (CDC)

The full load will copy the existing database into Amazon RDS.

CDC will then continue replicating `INSERT`, `UPDATE`, and `DELETE` activity from the source MySQL binary logs until production cutover.

### Source Migration Readiness

Technical discovery confirmed:

- Binary logging is enabled
- Binlog format is `ROW`
- Binlog row image is `FULL`
- Binlogs are retained for 30 days
- The source database is very small at approximately 0.05 MB

These settings are suitable for the planned full-load plus CDC migration.

### Sizing Reasoning

`dms.t3.micro` is appropriate for the lab because:

- The database is extremely small
- Transaction volume is low
- The migration is temporary
- A larger replication instance would provide little benefit for this workload

A larger replication instance would be selected in production if workload testing or migration monitoring showed that additional capacity was required.

### Production Recommendation

For a production migration, the recommended AWS DMS design would use a Multi-AZ replication instance.

Multi-AZ provides improved resilience during ongoing Change Data Capture.

If the primary DMS replication instance becomes unavailable, a standby instance in another Availability Zone can take over.

This reduces the risk of database replication being interrupted close to the production cutover window.

### Lab Implementation

For this temporary migration lab, AWS DMS will be deployed using a Single-AZ replication instance.

This reduces the cost of the hands-on environment while still allowing the full-load and CDC migration process to be tested.

The difference between the production recommendation and the lab implementation is a deliberate cost-saving decision rather than an architectural oversight.

---

## 13. Infrastructure as Code

The AWS target environment will be provisioned using Terraform.

### Reasoning

- Provides repeatable infrastructure deployment
- Keeps the AWS design version-controlled
- Makes configuration changes auditable
- Reduces manual configuration drift
- Allows the environment to be recreated consistently
- Supports clean teardown of the temporary migration lab

Terraform state will be stored remotely and protected appropriately.

## 14. IAM and Access Control Design

IAM permissions will follow the principle of least privilege.

AWS workloads will use IAM roles rather than long-term AWS access keys stored on the servers.

### Application EC2 IAM Role

The application EC2 instances will use an IAM instance role.

The role will allow the application to:

- Retrieve the required database secret from AWS Secrets Manager
- Send required metrics and logs to Amazon CloudWatch
- Perform only the AWS API actions required by the application

Secrets Manager access will be restricted to the specific database secret used by the Customer Portal.

The application instances will not receive broad administrative AWS permissions.

### File Server EC2 IAM Role

The file-server EC2 instance will use a separate IAM role.

The role will allow:

- CloudWatch monitoring and log delivery
- Any additional AWS access specifically required by the file-server workload

The file server does not require access to the application database secret.

### AWS DMS Permissions

AWS DMS will use the required IAM service roles to:

- Operate inside the VPC
- Access required networking resources
- Publish migration logs and monitoring information where configured

DMS permissions will be limited to those required for the migration.

### AWS Backup Permissions

AWS Backup will use an AWS Backup service role to perform backup and restore operations on the protected EC2 and EBS resources.

### Terraform Permissions

Terraform will run using an authorised AWS identity with sufficient permissions to create and manage the infrastructure defined by the project.

Long-term credentials will not be stored in Terraform configuration files or committed to Git.

Terraform state access will be restricted to authorised identities.

### Administrative Access

EC2 operating-system administration will use SSH through the Site-to-Site VPN.

SSH access will be restricted to the approved administrative source network.

No EC2 instance will require a public IP address for administration.

### Reasoning

- IAM roles avoid storing permanent AWS credentials on EC2 instances.
- Separate roles prevent the application and file server from receiving permissions they do not need.
- Access to Secrets Manager can be restricted to the exact secret required by the application.
- Least-privilege permissions reduce the impact of a compromised workload.
- AWS API activity can be audited through AWS logging services.

## 15. Secrets Manager Integration

The migrated Customer Portal will use AWS Secrets Manager to store the Amazon RDS database credentials.

### Source Configuration

The existing application retrieves the MySQL password from:

`/etc/legacy-app.env`

using the `DB_PASSWORD` environment variable.

This local credential-storage method will be replaced in the AWS environment.

### AWS Target Configuration

AWS Secrets Manager will store the credentials required to connect to Amazon RDS.

The secret will contain the required database connection information, including:

- Database username
- Database password
- RDS endpoint
- Database name
- Database port where required

### Application Access

The application EC2 instances will use their IAM instance role to retrieve the required secret.

The IAM role will be restricted to the specific Secrets Manager secret used by the Customer Portal.

No permanent AWS access keys will be stored on the EC2 instances.

### Application Change

A small application configuration change will be required so that the Flask application retrieves its database connection information from AWS Secrets Manager rather than relying solely on `/etc/legacy-app.env`.

This is considered a controlled migration configuration change rather than a wider application refactor.

### Security Benefits

- Database credentials are stored centrally.
- Secrets are encrypted at rest.
- Access is controlled through IAM.
- Credentials do not need to be hard-coded into application files.
- Secret access can be audited.
- The database password can be changed without storing the new value directly in the application source code.

### Lab Consideration

For the temporary lab, automatic secret rotation is not required.

In a production environment, rotation could be considered based on the customer's operational and security requirements.

## 16. DNS and Internal Application Access

The Customer Portal will use an internal DNS name rather than requiring users to access the AWS-generated Application Load Balancer hostname.

### Internal DNS Name

Planned application name:

`customerportal.company.local`

### DNS Target

The internal DNS record will resolve to the internal Application Load Balancer.

### Reasoning

- Users should access the application through a stable and recognisable hostname.
- The ALB-generated DNS name should not be exposed directly to users.
- A stable DNS name allows the underlying AWS infrastructure to change without requiring users to change how they access the portal.
- The application remains internal-only.
- DNS can be updated during cutover to direct users to the AWS environment.

### Cutover Use

Before migration:

`customerportal.company.local` points to the existing on-premises application environment.

During production cutover, the DNS record will be updated so that the hostname resolves to the internal AWS Application Load Balancer.

### DNS Considerations

- DNS TTL should be reduced before cutover so that changes propagate more quickly.
- The DNS update should only occur after the AWS environment has passed pre-cutover testing.
- The previous DNS value should be retained as part of the rollback plan.
- DNS resolution must be available to users connected through the corporate network or VPN.

### AWS DNS Integration

The final implementation may use Amazon Route 53 Private Hosted Zones or integration with the customer's existing internal DNS platform.

The exact implementation will depend on how the customer's corporate DNS is managed.

## 17. Backup and Recovery Design

The AWS target environment will use automated backup and recovery mechanisms for the application, database and file-server workloads.

### Amazon RDS Backups

Amazon RDS for MySQL will use automated backups with an initial retention period of:

`7 days`

RDS automated backups will provide:

- Automated database backups
- Transaction-log retention
- Point-in-time recovery within the configured retention window
- Recovery capability if database data is accidentally deleted or corrupted

The RDS Multi-AZ standby provides availability and failover but is not a replacement for backups.

### Application EC2 Backups

The application EC2 workloads will be protected using AWS Backup.

Protected data will include the application EC2/EBS resources containing:

- Operating-system configuration
- Nginx configuration
- Gunicorn configuration
- Flask application files
- systemd configuration
- Supporting application files

Initial retention:

`7 days`

### File Server Backups

The rehosted NFS file server will also be protected using AWS Backup.

The backup will protect the EBS storage containing:

`/srv/legacy-files`

Initial retention:

`7 days`

### Backup Vault

AWS Backup recovery points will be stored in a dedicated backup vault.

Backup resources will be encrypted at rest.

Access to backup and restore operations will be restricted through IAM permissions.

### Backup Scheduling

Backups will run automatically according to the configured AWS Backup plan.

Backup windows should avoid unnecessary impact during the customer's main business hours where practical.

### Restore Testing

Backup creation alone will not be considered sufficient proof of recoverability.

Restore testing will be performed to confirm that:

- An application-server recovery point can be restored
- The file-server data can be recovered
- Amazon RDS recovery procedures work as expected

### RPO Consideration

The customer's RPO of 0 cannot be achieved through periodic backups alone.

For the database migration, AWS DMS CDC will keep the RDS target synchronised with committed source changes until final cutover.

After migration, database resilience, automated backups and point-in-time recovery will provide significantly stronger data protection than the existing source environment.

### Lab Implementation

The lab will use a 7-day retention period to demonstrate automated backup and recovery while keeping the temporary environment cost-conscious.

In a production environment, backup frequency and retention would be agreed with the customer based on:

- Business requirements
- RPO and RTO
- Compliance requirements
- Data retention requirements
- Recovery expectations

## 18. Cost Management and Budget Controls

The AWS target architecture will be reviewed using the AWS Pricing Calculator before deployment.

The purpose is to estimate the expected monthly cost of the designed environment and identify any services that may create unnecessary expense for the temporary lab.

### Services to Include in the Cost Estimate

The estimate will include:

- 2 × `t3.small` application EC2 instances
- 1 × `t3.small` file-server EC2 instance
- gp3 EBS storage
- Internal Application Load Balancer
- 1 × Regional NAT Gateway operating across 2 Availability Zones
- Amazon RDS for MySQL Multi-AZ `db.t3.micro`
- RDS storage
- AWS DMS `dms.t3.micro`
- Site-to-Site VPN
- AWS Backup
- Amazon CloudWatch
- Amazon SNS
- AWS Secrets Manager
- Relevant data-transfer charges where applicable

### Budget Controls

AWS Budgets will be configured for the lab environment.

Budget notifications will be sent when spending approaches or exceeds agreed thresholds.

Example thresholds may include:

- 50% of the monthly lab budget
- 80% of the monthly lab budget
- 100% of the monthly lab budget

Notifications will be delivered through email or another approved notification channel.

### Cost Monitoring

Cost Explorer will be used to review:

- Current spend
- Spend by AWS service
- Unexpected cost increases
- High-cost resources
- Opportunities to remove or resize unused resources

### Lab Cost Considerations

The environment is temporary and will be destroyed after migration testing has completed.

Particular attention will be given to services that can generate noticeable ongoing cost, including:

- Regional NAT Gateway
- Multi-AZ Amazon RDS
- AWS DMS
- Application Load Balancer
- Site-to-Site VPN

Where the lab implementation differs from the production recommendation for cost reasons, the difference will be documented explicitly.

### Teardown

Terraform will be used to remove the temporary AWS infrastructure after the lab has been completed.

The teardown process will also verify that no unnecessary chargeable resources remain, including:

- Regional NAT Gateway
- Elastic IP addresses
- RDS resources
- DMS resources
- Load balancers
- EBS volumes
- Backup recovery points
- Snapshots
- VPN resources

### Reasoning

- Cost visibility should exist before infrastructure is deployed.
- Budgets and notifications reduce the risk of unexpected AWS charges.
- Cost Explorer provides ongoing visibility after deployment.
- Terraform supports controlled teardown of the temporary environment.

## 19. Terraform State and Repository Design

The AWS target environment will be provisioned and managed using Terraform.

Terraform configuration will be stored in the existing `aws-target` directory of the migration project.

### Remote Terraform State

Terraform state will be stored remotely in an Amazon S3 backend.

The state bucket will:

- Have public access blocked
- Use encryption at rest
- Have versioning enabled
- Restrict access through IAM
- Use Terraform state locking to prevent concurrent state modifications

The remote state infrastructure will be created separately from the migration workload so that running `terraform destroy` against the lab does not accidentally remove the state backend.

### State Protection

Terraform state files will not be:

- Stored permanently on the local workstation
- Committed to Git
- Published to GitHub
- Shared as project documentation

Sensitive Terraform values will not be deliberately exposed through outputs.

### Repository Structure

The existing project structure will be used:

```text
aws-migration-project/
│
├── on-prem/
│
├── aws-target/
│   ├── versions.tf
│   ├── providers.tf
│   ├── variables.tf
│   ├── locals.tf
│   ├── networking.tf
│   ├── security-groups.tf
│   ├── iam.tf
│   ├── ec2.tf
│   ├── alb.tf
│   ├── rds.tf
│   ├── dms.tf
│   ├── backup.tf
│   ├── monitoring.tf
│   ├── secrets.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
├── migration-docs/
│
├── scripts/
│
├── .gitignore
│
└── README.md
```

## 20. Target Architecture Summary

The target AWS environment will use a multi-AZ architecture in `eu-west-2`.

The workload will remain internal-only and will use private connectivity between the customer network and AWS.

### Target Architecture

```text
                           Corporate Users
                                 |
                                 |
                          Site-to-Site VPN
                                 |
                                 v
                      Virtual Private Gateway
                                 |
                                 v
                         VPC 10.20.0.0/16
                                 |
                         Regional NAT Gateway
                          (multi-AZ egress)
                                 |
                    +------------+------------+
                    |                         |
               eu-west-2a                eu-west-2b
                    |                         |
            app-private-a               app-private-b
              App EC2-A                   App EC2-B
                    \                       /
                     \                     /
                      v                   v
                         Internal ALB
                           HTTPS 443
                              |
                +-------------+-------------+
                |                           |
             RDS MySQL                 File EC2
             Multi-AZ                  NFS Server
                |                           |
           db-private-a/b              TCP 2049
                |
               DMS
                |
                | Site-to-Site VPN
                |
                v
        onprem-db01 during migration
```

## 21. Implementation Build Order

The AWS target environment will be implemented in dependency order so that foundational services exist before the workloads that rely on them.

### Phase 1 — Terraform Foundation

- Configure Terraform
- Configure AWS provider
- Create and protect the remote Terraform state backend
- Configure state locking
- Confirm Git exclusions for state and sensitive values

### Phase 2 — Networking

- Create VPC `10.20.0.0/16`
- Create private application subnets
- Create private database subnets
- Attach Internet Gateway
- Create application and database route tables
- Create 1 Regional NAT Gateway
- Configure the Regional NAT Gateway across the workload Availability Zones
- Route application-subnet internet traffic through the Regional NAT Gateway
- Create Virtual Private Gateway
- Configure Site-to-Site VPN
- Configure routing to `192.168.56.0/24`
- Validate private connectivity between on-premises and AWS

### Phase 3 — Security and IAM

- Create ALB Security Group
- Create application Security Group
- Create RDS Security Group
- Create file-server Security Group
- Create DMS Security Group if required
- Create EC2 IAM roles
- Create DMS service roles
- Create AWS Backup service roles
- Apply least-privilege access controls

### Phase 4 — Secrets Management

- Create the database secret in AWS Secrets Manager
- Restrict secret access to the application IAM role
- Confirm credentials are not stored in Git or Terraform configuration

### Phase 5 — Database Target

- Create RDS DB subnet group
- Deploy Amazon RDS for MySQL
- Configure Multi-AZ
- Configure `db.t3.micro`
- Configure 20 GiB gp3 storage
- Enable encryption
- Enable 7-day automated backups
- Confirm RDS is private
- Test database connectivity

### Phase 6 — File Server

- Replicate `onprem-file01`
- Launch the rehosted EC2 file server
- Configure 20 GiB encrypted gp3 storage
- Validate NFS service
- Validate `/srv/legacy-files`
- Validate permissions and ownership
- Test NFS connectivity

### Phase 7 — Application Load Balancer

- Create internal ALB
- Create target group
- Configure health checks
- Configure HTTPS listener
- Configure TLS certificate
- Validate internal ALB connectivity

### Phase 8 — Application Layer

- Replicate `onprem-app01`
- Create EC2 launch template
- Configure `t3.small`
- Configure 20 GiB encrypted gp3 storage
- Create Auto Scaling Group
- Set minimum capacity to 2
- Set desired capacity to 2
- Set maximum capacity to 4
- Deploy across both application subnets
- Register application instances with the ALB
- Update database configuration for Amazon RDS
- Configure Secrets Manager integration
- Update NFS mount configuration
- Validate application functionality

### Phase 9 — AWS DMS

- Create DMS replication subnet group
- Deploy `dms.t3.micro`
- Use Single-AZ for the lab
- Create source MySQL endpoint
- Create Amazon RDS target endpoint
- Test source connectivity
- Test target connectivity
- Create the full-load plus CDC migration task

### Phase 10 — Monitoring and Alerting

- Configure CloudWatch Agent
- Configure CloudWatch Logs
- Configure CloudWatch metrics
- Configure CloudWatch Alarms
- Create SNS notification topic
- Configure email notifications
- Validate alert delivery

### Phase 11 — Backup and Recovery

- Create AWS Backup vault
- Create AWS Backup plan
- Protect application EC2/EBS resources
- Protect file-server EC2/EBS resources
- Validate backup creation
- Perform restore testing

### Phase 12 — Cost Controls

- Configure AWS Budgets
- Configure budget alerts
- Review Cost Explorer
- Monitor temporary high-cost resources

### Phase 13 — Database Migration

- Start DMS full load
- Validate migrated database data
- Start or continue CDC
- Monitor replication lag
- Keep the source database active until final cutover

### Phase 14 — Pre-Cutover Testing

- Test the complete AWS application path
- Validate RDS data
- Validate NFS access
- Validate HTTPS access
- Validate monitoring and alerts
- Validate backup and rollback procedures

### Phase 15 — Production Cutover

- Enter approved maintenance window
- Stop application writes
- Allow DMS CDC to reach zero lag
- Validate final database state
- Update production DNS
- Validate the AWS Customer Portal
- Re-enable user access

### Phase 16 — Post-Cutover and Teardown

- Monitor the production workload
- Obtain customer acceptance
- Retain source systems during the agreed rollback period
- Stop DMS when no longer required
- Decommission the source environment after approval
- Destroy the temporary AWS lab using Terraform when testing is complete
- Verify that no unnecessary chargeable AWS resources remain


# AWS On-Premises to AWS Migration Project

A hands-on portfolio project demonstrating an end-to-end migration of a simulated on-premises three-tier application into AWS.

The project covers discovery, assessment, architecture, Infrastructure as Code, private hybrid connectivity, database migration, file migration, server rehosting, cutover, validation and post-migration cleanup.

> This is a personal lab/portfolio project designed to demonstrate practical AWS migration skills. It should not be interpreted as production customer migration experience.

---

## Project Overview

The starting environment simulated a small on-premises application estate consisting of:

- Linux application server
- MySQL database server
- NFS file server
- Site-to-Site VPN gateway

The final AWS environment uses:

- Amazon VPC
- Private application and database subnets
- Amazon EC2
- Amazon RDS for MySQL
- AWS Database Migration Service (DMS)
- AWS Application Migration Service (MGN)
- AWS Site-to-Site VPN
- Amazon EBS
- AWS Secrets Manager
- IAM
- Amazon S3 remote Terraform state
- Terraform

The migration was completed using a mixture of AWS Console, AWS CLI, Linux, PowerShell and Terraform.

---

# Migration Architecture

## Source Environment

The simulated on-premises environment was built using VirtualBox and Ubuntu Server.

| Server | Address | Role |
|---|---|---|
| `onprem-app01` | `192.168.56.10` | Flask / Gunicorn / Nginx application |
| `onprem-db01` | `192.168.56.20` | MySQL 8 database |
| `onprem-file01` | `192.168.56.30` | NFS file server |
| `onprem-vpn01` | `192.168.56.254` | strongSwan VPN gateway |

On-premises network:

```text
192.168.56.0/24
````

---

## AWS Target Environment

AWS Region:

```text
eu-west-2
```

VPC:

```text
10.20.0.0/16
```

Private application subnets:

```text
10.20.1.0/24 - eu-west-2a
10.20.2.0/24 - eu-west-2b
```

Private database subnets:

```text
10.20.3.0/24 - eu-west-2a
10.20.4.0/24 - eu-west-2b
```

The application and database workloads are not directly exposed to the public internet.

---

# Migration Strategy

Different migration approaches were selected for each workload.

| Workload             | Strategy            | AWS Service                       |
| -------------------- | ------------------- | --------------------------------- |
| Application server   | Rehost              | AWS Application Migration Service |
| MySQL database       | Replatform          | Amazon RDS + AWS DMS              |
| File server          | Rehost              | EC2 + encrypted EBS               |
| Network connectivity | Hybrid connectivity | AWS Site-to-Site VPN              |

This demonstrates that a migration does not need to use the same strategy for every workload.

---

# Migration Process

## 1. Discovery

Technical discovery was performed against the original Linux servers to identify:

* Operating systems
* CPU and memory
* Storage
* IP configuration
* Running services
* Open ports
* Application dependencies
* Database configuration
* NFS exports
* Application-to-database connectivity

A reusable Linux discovery script was also created:

```text
scripts/linux-discovery.sh
```

Discovery evidence is stored under:

```text
migration-docs/
```

---

## 2. Assessment and Migration Planning

Each workload was assessed before migration.

The project documented:

* Existing architecture
* Dependencies
* Migration risks
* Migration strategy
* AWS target design
* Production recommendations
* Lab-specific cost decisions
* Estimated AWS production costs

---

## 3. AWS Infrastructure with Terraform

The AWS target environment was created using Terraform.

Terraform manages infrastructure including:

* VPC
* Private subnets
* Route tables
* Regional NAT Gateway
* Virtual Private Gateway
* Customer Gateway
* Site-to-Site VPN
* Security groups
* Amazon RDS
* AWS DMS resources
* AWS file server
* IAM roles
* MGN supporting IAM resources

Terraform configuration is stored in:

```text
aws-target/
```

The final Terraform validation returned:

```text
No changes. Your infrastructure matches the configuration.
```

This confirmed the live Terraform-managed infrastructure matched the configuration after final migration cleanup.

---

# Hybrid Networking

An AWS Site-to-Site VPN was established between the simulated on-premises environment and AWS.

The on-premises VPN gateway uses:

```text
strongSwan
```

Application route tables contain routes for:

```text
10.20.0.0/16     -> VPC local routing
0.0.0.0/0        -> Regional NAT Gateway
192.168.56.0/24  -> Virtual Private Gateway
```

The database subnet route table intentionally remains private and does not require direct internet routing.

The VPN was configured with:

```text
Tunnel 1 - Active
Tunnel 2 - Standby
```

During cutover testing, the ISP public IP changed and caused the VPN to fail.

Terraform was updated to safely replace the AWS Customer Gateway using:

```hcl
lifecycle {
  create_before_destroy = true
}
```

The VPN was successfully restored and the migration continued.

---

# Database Migration

The original database ran:

```text
MySQL 8.0
```

Source database:

```text
legacy_app
```

Baseline data:

```text
customers = 53
orders    = 100
```

The target database was Amazon RDS for MySQL.

Target configuration included:

* MySQL 8
* Multi-AZ
* Private networking
* 20 GiB gp3
* Encryption enabled
* 7-day backup retention
* RDS-managed master credentials

AWS Database Migration Service was configured using:

```text
Full load + Change Data Capture
```

Validation included:

* Initial full load
* CDC INSERT
* CDC UPDATE
* CDC DELETE
* Source endpoint connection test
* Target endpoint connection test
* Final row-count validation

Final result:

```text
customers = 53
orders    = 100
```

DMS table statistics recorded:

```text
Tables completed = 2
Table errors    = 0
Full load       = 100%
```

---

# File Server Migration

The original NFS workload was migrated to an EC2-based file server.

Target configuration:

* Ubuntu Server
* `t3.small`
* Private subnet
* 20 GiB gp3 EBS
* EBS encryption enabled
* NFS

Target NFS location:

```text
10.20.1.92:/srv/legacy-files
```

Application mount point:

```text
/mnt/legacy-files
```

Migration validation included:

* File count comparison
* Directory count comparison
* Permissions
* Ownership
* SHA-256 hashes
* Initial rsync
* Final delta rsync
* Read testing
* Write testing

Final migrated files included:

```text
test.txt
uploads/contract-001.txt
uploads/invoice-001.txt
uploads/report-001.txt
```

---

# Application Migration with AWS MGN

AWS Application Migration Service was used to rehost the original application server.

Source:

```text
onprem-app01
192.168.56.10
```

MGN replication was configured to use private networking across the Site-to-Site VPN.

Replication traffic was restricted to:

```text
TCP 1500
192.168.56.10/32
```

A replication backlog test was deliberately created by writing approximately 512 MiB of data to the source server.

MGN successfully reduced the backlog back to:

```text
0
```

This demonstrated continuous replication catching up with source changes.

---

# MGN Test Migration

Before final cutover, an MGN test instance was launched.

The migrated application initially returned:

```text
HTTP 500
```

Troubleshooting identified that the application still contained the original on-premises MySQL address.

The application configuration was updated to use:

* Amazon RDS for MySQL
* AWS NFS file server

The application database user was also recreated on RDS with restricted permissions:

```text
SELECT
INSERT
UPDATE
DELETE
```

After remediation:

```text
HTTP 200
Customers in database: 53
```

NFS read and write tests also passed.

---

# Final Cutover

Before final cutover:

* Final file delta synchronization was completed
* Original application service was stopped
* Configuration backups were created
* Application database configuration was changed to RDS
* NFS configuration was changed to the AWS file server
* MGN replication backlog returned to zero

The final EC2 application server was launched successfully.

Final application server:

```text
Private IP: 10.20.1.121
Public IPv4: None
Instance type: c5.large
```

MGN was then finalized and replication disconnected.

---

# Final Validation

The final migrated application was tested from the AWS EC2 instance.

Application test:

```bash
curl -i http://localhost
```

Result:

```text
HTTP/1.1 200 OK

Legacy Customer Portal
Application server: onprem-app01
Customers in database: 53
```

Database validation:

```text
customers = 53
orders    = 100
```

NFS validation confirmed:

```text
10.20.1.92:/srv/legacy-files
```

was mounted successfully on:

```text
/mnt/legacy-files
```

All expected migrated files were present.

---

# Security Controls

Security was treated as part of the migration rather than an afterthought.

## Application EC2

The final application server:

* Uses a private IP
* Has no public IPv4 address
* Runs inside a private application subnet
* Uses encrypted EBS storage

Application security-group access includes:

```text
SSH 22  <- on-premises VPN network
HTTP 80 <- application-tier security control
```

---

## Database

Amazon RDS is:

* Multi-AZ
* Encrypted
* Not publicly accessible
* Located in private database subnets

MySQL traffic on TCP 3306 is restricted to:

* Application security group
* DMS security group

---

## File Server

NFS TCP 2049 is restricted to the application security group.

SSH administration is restricted to the on-premises network across the VPN.

---

## MGN Replication

MGN replication access was restricted to:

```text
TCP 1500
Source: 192.168.56.10/32
```

---

## Secrets

Passwords, VPN pre-shared keys, private keys and AWS credentials are not stored in this repository.

RDS master credentials are managed by AWS Secrets Manager.

Sensitive local files are excluded through `.gitignore`.

---

# Terraform Remote State

Terraform state is stored remotely in Amazon S3.

The backend uses:

```text
aws-target/terraform.tfstate
```

State-bucket protection includes:

* S3 Versioning enabled
* Default encryption enabled
* Block Public Access enabled
* Terraform state locking enabled

Terraform state files are excluded from Git.

---

# Troubleshooting Examples

The project intentionally documents problems encountered during the migration rather than only showing the successful result.

Examples include:

### MGN IAM Role Path

MGN service roles were initially created under:

```text
/
```

but AWS expected them under:

```text
/service-role/
```

CloudTrail helped identify an `iam:PassRole` failure.

The Terraform IAM configuration was corrected.

---

### MGN Agent Authentication

After MGN IAM roles were replaced, the source replication agent reported an invalid security token.

The agent was safely reinstalled using temporary STS credentials.

Replication resumed without creating a new source-server identity.

---

### Application HTTP 500

The MGN test instance initially failed because the application still referenced the original database IP.

The dependency was identified and changed to Amazon RDS.

---

### Site-to-Site VPN Failure

The on-premises public IP changed during the project, breaking the Customer Gateway configuration.

The AWS Customer Gateway was replaced and Terraform was improved using:

```hcl
create_before_destroy = true
```

---

### SSH Cutover Troubleshooting

The final migrated instance initially appeared unreachable over SSH.

Investigation included:

* EC2 health checks
* SSH service status
* local SSH testing
* firewall checks
* EC2 Serial Console
* packet capture
* VPN status

The EC2 instance itself was healthy.

The root cause was the failed Site-to-Site VPN following the public IP change.

---

# Production vs Lab Decisions

This project deliberately separates production recommendations from cost-saving lab decisions.

Examples:

### DMS

Lab:

```text
Single-AZ replication instance
```

Production recommendation:

```text
Multi-AZ replication instance
```

This would provide better resilience during ongoing CDC and cutover.

---

### Rollback

The original VirtualBox source systems were retained after cutover rather than immediately destroyed.

This represents a realistic rollback/acceptance window.

---

# Important Architecture Note

An Application Load Balancer security-group design was created during the infrastructure design phase.

However, an Application Load Balancer was **not deployed and validated as part of the completed migration**.

The final application validation was performed directly against the private migrated EC2 instance.

This distinction is intentional so the portfolio accurately represents what was actually implemented and tested.

---

# Repository Structure

```text
aws-migration-project/
|
|-- aws-target/
|   |-- database.tf
|   |-- dms.tf
|   |-- file-server.tf
|   |-- iam.tf
|   |-- locals.tf
|   |-- mgn-iam.tf
|   |-- networking.tf
|   |-- providers.tf
|   |-- security-groups.tf
|   |-- variables.tf
|   |-- versions.tf
|   `-- .terraform.lock.hcl
|
|-- migration-docs/
|   |-- 01-on-prem-network-plan.md
|   |-- 02-source-inventory.md
|   |-- 03-technical-discovery.md
|   |-- 04-source-assessment.md
|   |-- 05-migration-strategy.md
|   |-- 06-aws-target-architecture.md
|   |-- 07-production-cost-estimate.md
|   `-- discovery evidence
|
|-- scripts/
|   `-- linux-discovery.sh
|
|-- README.md
`-- .gitignore
```

---

# Technologies Used

### AWS

* Amazon EC2
* Amazon RDS
* AWS Database Migration Service
* AWS Application Migration Service
* Amazon VPC
* AWS Site-to-Site VPN
* NAT Gateway
* Amazon EBS
* Amazon S3
* AWS Secrets Manager
* IAM
* CloudTrail

### Infrastructure and Operations

* Terraform
* AWS CLI
* PowerShell
* Linux
* Bash
* SSH
* strongSwan
* VirtualBox
* Git
* GitHub

### Application

* Ubuntu Server
* Nginx
* Gunicorn
* Flask
* MySQL
* NFS

---

# Key Outcomes

The project successfully demonstrated:

* Technical workload discovery
* Migration assessment and planning
* Multi-tier AWS architecture design
* Infrastructure as Code using Terraform
* Private subnet design
* Hybrid AWS/on-premises networking
* Site-to-Site VPN troubleshooting
* MySQL replatforming to Amazon RDS
* Full-load and CDC database migration
* File-server migration and integrity validation
* EC2 rehosting using AWS MGN
* MGN test migration before cutover
* Application dependency troubleshooting
* Final production-style cutover
* Post-cutover validation
* Least-privilege security controls
* Migration rollback considerations
* Terraform drift validation
* Secure remote state management

---

# Final Result

The migration finished with:

```text
MGN cutover             COMPLETE
Application validation  PASSED
RDS validation          PASSED
NFS validation          PASSED
VPN validation          PASSED
DMS migration           PROVEN
Terraform validation    NO CHANGES
```

The final migrated application runs privately in AWS and successfully accesses both the replatformed RDS database and migrated AWS NFS file server.

---

## Author

AWS migration portfolio project created to develop and demonstrate practical cloud infrastructure, migration, networking and Terraform skills.

```

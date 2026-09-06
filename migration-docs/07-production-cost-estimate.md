@'
# Production AWS Cost Estimate

## Purpose

This document records the estimated steady-state monthly cost of the planned AWS production environment for the Customer Portal.

The estimate is based on the target architecture defined in:

`06-aws-target-architecture.md`

The objective is to show the customer's lowest sensible long-term production cost rather than the temporary cost of the migration lab.

Where long-term commitments are available, 3-year pricing has been used to reduce the effective monthly cost.

AWS DMS and other migration-only services are excluded from the steady-state production total because they are not expected to remain after migration.

---

## 1. Production Cost Summary

| Service | Production Configuration | Effective Monthly Cost |
|---|---|---:|
| Application EC2 | 2 × `t3.small`, 20 GiB gp3 each | $16.71 |
| File Server EC2 | 1 × `t3.small`, 20 GiB gp3 | $8.36 |
| Regional NAT Gateway | 1 Regional NAT Gateway across 2 AZs | $73.25 |
| Amazon RDS for MySQL | Multi-AZ `db.t3.micro`, 20 GiB gp3 | $18.90 |
| Site-to-Site VPN | 1 VPN connection | $36.50 |
| Internal Application Load Balancer | 1 internal ALB | $19.32 |
| AWS Secrets Manager | 1 application database secret | $0.45 |
| AWS Backup | Daily EBS backups, 7-day retention | $0.84 |
| Amazon CloudWatch | Logs, metrics, alarms and dashboard | $15.22 |
| Amazon SNS | Low-volume email alerting | ~$0.00 |
| AWS Budgets | Basic cost budget and notifications | ~$0.00 |
| Internal DNS / certificate | Existing customer DNS and internal certificate authority | $0.00 |
| Public IPv4 addresses | Estimated NAT/VPN public IPv4 usage | ~$14.60 |
| Terraform S3 backend | Small encrypted/versioned state bucket | ~$0.05 |

### Estimated Effective Monthly Production Cost

**Approximately $204.20 per month**

This figure excludes variable data-transfer charges and temporary migration services.

---

## 2. Long-Term Compute Commitments

### Application EC2

Production application capacity:

- 2 × `t3.small`
- 3-year EC2 Instance Savings Plan
- All Upfront
- 20 GiB gp3 EBS per instance

Per instance:

- Upfront compute commitment: $233.89
- Monthly recurring EBS cost: $1.86
- Effective monthly-equivalent cost: approximately $8.36

For two application instances:

- Total upfront compute commitment: $467.78
- Effective monthly-equivalent cost: approximately $16.71

### File Server EC2

Production file-server capacity:

- 1 × `t3.small`
- 3-year EC2 Instance Savings Plan
- All Upfront
- 20 GiB gp3 EBS

Costs:

- Upfront compute commitment: $233.89
- Monthly recurring EBS cost: $1.86
- Effective monthly-equivalent cost: approximately $8.36

### Amazon RDS for MySQL

Production database:

- Multi-AZ
- `db.t3.micro`
- 20 GiB gp3
- 3-year Reserved pricing
- Long-term committed pricing selected for lowest overall cost

Costs:

- Upfront cost: $489.00
- Monthly recurring cost: $5.32
- Effective monthly-equivalent cost: approximately $18.90

---

## 3. Total Upfront Commitment

The long-term production estimate currently includes the following upfront commitments:

| Resource | Upfront Cost |
|---|---:|
| 2 × Application EC2 | $467.78 |
| 1 × File Server EC2 | $233.89 |
| Amazon RDS | $489.00 |

### Total Upfront Commitment

**$1,190.67**

Spread across the 36-month commitment period, this represents approximately:

**$33.07 per month**

of the effective monthly production cost.

---

## 4. Expected Recurring Monthly Bill After Upfront Payments

After the upfront EC2 and RDS commitments have been paid, the remaining estimated recurring AWS charges are approximately:

**$171.13 per month**

plus variable data-transfer charges.

The difference between this figure and the $204.20 effective monthly cost represents the monthly-equivalent value of the upfront commitments.

---

## 5. Variable Costs

The following costs may change depending on actual production usage:

- Internet and inter-AZ data transfer
- NAT Gateway data processing
- VPN data transfer
- ALB processed data / LCU usage
- CloudWatch log ingestion
- CloudWatch Logs Insights queries
- Backup growth
- EBS storage growth
- RDS storage growth
- Secrets Manager API usage
- Public IPv4 usage

The workload is currently small, so the estimates use relatively low utilisation assumptions.

Actual production usage should be reviewed through AWS billing and monitoring tools after migration.

---

## 6. Migration-Only Costs

The following services are required during migration but are not included in the steady-state monthly production total:

- AWS Database Migration Service
- AWS Application Migration Service
- Temporary replication resources
- Temporary migration staging storage
- Additional migration-related data transfer

AWS DMS will use a `dms.t3.micro` Single-AZ replication instance for the lab.

The production recommendation remains Multi-AZ DMS for improved migration resilience.

Migration-only resources should be removed when they are no longer required.

---

## 7. Cost Controls

The production environment should use:

- AWS Budgets
- Budget threshold notifications
- Cost Explorer
- Resource tagging
- Regular cost review
- Right-sizing based on CloudWatch metrics

Cost alerts should notify the relevant team if expenditure approaches or exceeds the agreed customer budget.

---

## 8. Cost Optimisation Notes

The largest fixed networking cost in the current design is the NAT capability.

The current design prioritises resilience across two Availability Zones.

Potential future optimisation should only be performed if it does not conflict with the customer's availability, security or connectivity requirements.

The following resources should also be reviewed after production usage data becomes available:

- EC2 instance sizes
- RDS instance size
- Backup retention
- CloudWatch log retention
- NAT usage
- Application Auto Scaling thresholds

---

## 9. Estimate Status

**Production cost estimate status: COMPLETE**

Estimated steady-state production cost:

**~$204.20/month**

Estimated upfront 3-year commitment:

**$1,190.67**

Expected recurring monthly AWS bill after upfront commitments:

**~$171.13/month**

Variable data-transfer charges are not included in the fixed estimate.

Migration-only AWS resources are also excluded from the steady-state production total.
'@ | Set-Content ".\migration-docs\07-production-cost-estimate.md"
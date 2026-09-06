# Source Discovery Environment

## 1. Customer Migration Scope

What does the customer want migrated?

Customer answer: 

The customer wants to migrate:

- Customer Portal web application
- MySQL customer and orders database
- Shared business files stored on the file server

The customer wants all three workloads moved to AWS with as little downtime as possible.

## 2. Current Server Information

What servers currently support the Customer Portal, database and file storage?

Please provide, if known:

- Server name
- Server purpose
- Operating system
- Physical or virtual
- Server location

Customer answer:

- onprem-app01 - hosts the Customer Portal - Ubuntu Server - Virtual machine - On-premises server environment
- onprem-db01 - hosts the MySQL database - Ubuntu Server - Virtual machine - On-premises server environment
- onprem-file01 - stores shared business files - Ubuntu Server - Virtual machine - On-premises server environment

The customer is not certain of the exact Ubuntu versions or detailed server specifications, so these will need to be verified during technical discovery

## 3. Application Dependencies

How do the three servers work together?

Please explain, if known:

- Which server the Customer Portal connects to
- Which server stores the database
- Which server stores the shared files
- Any known ports or protocols used
- Whether any other systems depend on these servers

Customer answer:

- onprem-app01 hosts the Customer Portal
- The application connects to onprem-db01 for customer and order data
- The application uses onprem-file01 for shared business files and uploads
- The customer believes the database connection uses MySQL
- The customer is unsure of the exact ports/protocols used and these will need to be verified 
- No other systems are currently known to depend on these servers

## 4. Business Criticality and Downtime

How important is the Customer Portal to the business?

Please provide, if known:

- Normal hours of use
- How many users depend on it
- Maximum acceptable downtime
- Whether maintenance windows are available 
- What impact an outage would have on the business

Customer answers:

- The customer states the normal hours of use is Monday-Friday, 7-7
- 53 users depend on all three servers
- Customer states the maximum acceptable downtime is 1 hour
- The customer states a maintenance window is available outside normal business hours, preferably evenings or weekends
- The customer stated that anything over an hour would be critical to the business

## 5. Recovery Objectives and Data Loss

How much data could the customer afford to lose if something went wrong during the migration or after cutover?

Please provide, if known:

- Maximum acceptable data loss
- How quickly the service must be restored
- Whether backups currently exist
- How often backups are taken
- How long backups are retained

Customer answers:

- The customer has strictly stated that zero data loss is acceptable
- Within the hour
- There are no current recent backups
- The customer states that they run a backup once per month but that sometimes gets neglected
- The customer does not know how long the retention period is for the backups

## 6. Security and Access Requirements

What security requirements apply to the Customer Portal and its data?

Please provide, if known:

- What type of data is stored
- Whether any data is sensitive or confidential
- Who is allowed to access the application
- How users currently authenticate
- Whether there are any compliance requirements
- Whether server access is restricted to specific administrators

Customer answers:

- The Customer Portal stores customer names, email addresses and order information
- The customer considers this business data confidential
- Only authorised employees should be able to access the Customer Portal
- Users currently authenticate using application usernames and passwords
- The customer is not aware of any formal compliance requirements
- Server administration is restricted to authorised IT administrators only

## 7. Network and Connectivity Requirements

How do users currently access the Customer Portal and how does the environment connect to other networks?

Please provide, if known:

- Whether users access it internally, externally, or both
- Current DNS/URL used
- Whether remote users require VPN access
- Whether the servers need internet access
- Whether there are any firewall rules or network restrictions
- Whether the customer has an existing connection to AWS

Customer answers:

- The Customer Portal is currently available only from the corporate internal network
- Employees access the application using the internal DNS name customerportal.company.local
- Remote employees must first connect to the corporate VPN before they can access the portal
- The servers require limited outbound internet access for operating-system updates and software downloads
- Existing firewall rules are understood to allow:
  - HTTP traffic to the application server
  - MySQL traffic only between onprem-app01 and onprem-db01
  - NFS traffic only between onprem-app01 and onprem-file01
  - SSH access only for authorised IT administrators
- The customer does not currently have any private connectivity to AWS
- The customer wants the migrated AWS environment to remain privately connected to the existing on-premises network during the migration period

This means we will need to design **temporary hybrid connectivity between the on-prem environment and AWS** so data can migrate while the existing system remains operational.

## Data Volume and Growth 

How much data is currently stored and how quickly is it growing?

Please provide, if known:

- Current database size
- Current file-server storage used
- Approximate number of database records
- Average number of new orders or records created each day
- Approximate number/size of new files uploaded each day
- Whether the customer expects usage to grow significantly over the next 1–3 years

Customer answers:

- The customer estimates the MySQL database is currently under 1 GB but does not know the exact size
- The customer estimates approximately 2 GB of business files are stored on the file server
- The customer is unsure of the exact number of database records and wants this verified during technical discovery
- Approximately 20–40 new orders are created each business day
- Approximately 5–10 new documents or files are uploaded each day
- The customer expects usage to gradually increase over the next 1–3 years as more employees and customers use the system
- The customer would like the AWS design to allow storage and database capacity to grow without requiring major infrastructure changes

## 9. Current Availability and Resilience

What happens today if one of the servers fails?

Please provide, if known:

- Whether any server has redundancy
- Whether the application can continue if onprem-app01 fails
- Whether the database has replication or failover
- Whether the file server has any replica or secondary copy
- Whether spare infrastructure is available
- How failures are currently detected and handled

Customer answers:

- None of the three servers currently has redundancy
- If onprem-app01 fails, the Customer Portal becomes unavailable
- The MySQL database on onprem-db01 has no replication or automatic failover
- The file server on onprem-file01 has no replica or secondary copy
- No spare infrastructure is currently available for immediate failover
- Failures are mainly detected when users report that the application is unavailable or when IT manually checks the servers
- Recovery currently depends on troubleshooting and restoring the failed server manually
- The customer wants the AWS target environment to improve availability and reduce the impact of a single server failure

## 10. Performance and Usage Patterns

How is the system used during a normal working day?

Please provide, if known:

- Number of concurrent users
- Busy periods
- Whether users currently report slow performance
- Typical response-time expectations
- Any scheduled jobs or batch processes
- Whether database or file usage increases significantly at certain times

Customer answers:

- Around 20–30 users may be active at the same time during normal working hours
- The busiest periods are usually between 09:00–11:00 and 14:00–16:00
- Users occasionally report slow page loads during busy periods
- The customer expects normal pages to respond within a few seconds
- There are no major scheduled batch jobs, but database backups may run outside business hours
- Database activity increases during busy periods as users create and update orders
- File usage is usually light, but larger document uploads can temporarily increase storage and network activity

## 11. Migration Constraints and Change Control

What restrictions could affect the migration?

Please provide, if known:

- Approved maintenance windows
- Changes that require customer approval
- Whether production changes must be tested first
- Who gives final cutover approval
- Whether rollback must be possible
- Any dates when migration work cannot happen

Customer answers:

- Approved migration work should take place outside normal business hours, preferably evenings or weekends
- Any production change affecting the Customer Portal, database, DNS, firewall rules or user access requires customer approval
- All migration changes must be tested in a non-production or test phase before final cutover
- Final cutover approval must be given by the customer’s IT lead or nominated business owner
- A rollback plan is mandatory and the existing on-prem environment must remain available until the migration is accepted
- No migration work should take place during month-end processing or other agreed business-critical periods

## 12. Migration Success Criteria

What must be true before the customer will consider the migration successful?

Please provide, if known:

- Customer Portal must be accessible and working
- Database data must be complete and accurate
- Shared files must be available
- Performance must be acceptable
- Monitoring and backups must be working
- Security requirements must be met
- Downtime must remain within the agreed 1-hour limit
- Customer must approve the final migrated environment

Customer answers:

- The Customer Portal must be fully accessible and all key functions must work correctly
- All customer and order data must be migrated with no data loss
- All shared business files must be available from the migrated environment
- Application performance must be equal to or better than the existing environment
- Backups, monitoring and alerting must be configured and tested
- Security and access controls must meet the agreed requirements
- Total cutover downtime must remain within the agreed maximum of 1 hour
- The existing on-premises environment must remain available until rollback is no longer required
- The customer’s IT lead and business owner must complete final validation and approve the migrated AWS environment

## 13. Application Ownership and Support

Who currently owns and supports the Customer Portal?

Please provide, if known:

- Whether the application was developed internally or by a third party
- Who supports the application today
- Whether any software licences are required
- Whether any vendor contracts or support agreements exist
- Whether there are configuration files, certificates or licence keys that must move with the application
- Who can approve application changes

Customer answers:

- The Customer Portal was developed internally several years ago
- The customer’s internal IT team currently supports the application and servers
- No commercial software licences are believed to be required
- There are no known third-party support contracts for the application
- The customer believes application configuration files will need to be migrated, but is unsure whether any certificates or other dependencies exist
- Application changes must be approved by the customer’s IT lead
- Any unknown application dependencies must be identified during technical discovery

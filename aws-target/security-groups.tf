# ============================================================
# Security Groups
# ============================================================

resource "aws_security_group" "alb" {
  name        = "${local.name_prefix}-alb-sg"
  description = "Security group for the internal Application Load Balancer"
  vpc_id      = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-alb-sg"
  })
}

resource "aws_security_group" "app" {
  name        = "${local.name_prefix}-app-sg"
  description = "Security group for application EC2 instances"
  vpc_id      = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-sg"
  })
}

resource "aws_security_group" "db" {
  name        = "${local.name_prefix}-db-sg"
  description = "Security group for Amazon RDS MySQL"
  vpc_id      = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-sg"
  })
}

resource "aws_security_group" "file" {
  name        = "${local.name_prefix}-file-sg"
  description = "Security group for the rehosted NFS file server"
  vpc_id      = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-file-sg"
  })
}

resource "aws_security_group" "dms" {
  name        = "${local.name_prefix}-dms-sg"
  description = "Security group for AWS DMS"
  vpc_id      = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dms-sg"
  })
}


# ============================================================
# ALB Security Group Rules
# ============================================================

# On-premises users -> Internal ALB HTTPS
resource "aws_vpc_security_group_ingress_rule" "alb_https_from_onprem" {
  security_group_id = aws_security_group.alb.id

  cidr_ipv4   = var.onprem_cidr
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443

  description = "Allow HTTPS from on-premises network over VPN"
}

# Internal ALB -> Application servers HTTP
resource "aws_vpc_security_group_egress_rule" "alb_http_to_app" {
  security_group_id = aws_security_group.alb.id

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80

  description = "Allow HTTP to application servers"
}


# ============================================================
# Application Security Group Rules
# ============================================================

# Internal ALB -> Application servers
resource "aws_vpc_security_group_ingress_rule" "app_http_from_alb" {
  security_group_id = aws_security_group.app.id

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80

  description = "Allow HTTP from internal ALB"
}

# On-premises administration -> Application servers
resource "aws_vpc_security_group_ingress_rule" "app_ssh_from_onprem" {
  security_group_id = aws_security_group.app.id

  cidr_ipv4   = var.onprem_cidr
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22

  description = "Allow SSH from on-premises network over VPN"
}

# Application servers -> RDS MySQL
resource "aws_vpc_security_group_egress_rule" "app_mysql_to_db" {
  security_group_id = aws_security_group.app.id

  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306

  description = "Allow MySQL to Amazon RDS"
}

# Application servers -> NFS file server
resource "aws_vpc_security_group_egress_rule" "app_nfs_to_file" {
  security_group_id = aws_security_group.app.id

  referenced_security_group_id = aws_security_group.file.id
  from_port                    = 2049
  ip_protocol                  = "tcp"
  to_port                      = 2049

  description = "Allow NFS to file server"
}

# Application servers -> AWS APIs / software repositories
resource "aws_vpc_security_group_egress_rule" "app_https_outbound" {
  security_group_id = aws_security_group.app.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443

  description = "Allow HTTPS outbound through Regional NAT Gateway"
}


# ============================================================
# Database Security Group Rules
# ============================================================

# Application servers -> RDS MySQL
resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_app" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306

  description = "Allow MySQL from application servers"
}

# AWS DMS -> RDS MySQL
resource "aws_vpc_security_group_ingress_rule" "db_mysql_from_dms" {
  security_group_id = aws_security_group.db.id

  referenced_security_group_id = aws_security_group.dms.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306

  description = "Allow MySQL from AWS DMS"
}


# ============================================================
# File Server Security Group Rules
# ============================================================

# Application servers -> NFS
resource "aws_vpc_security_group_ingress_rule" "file_nfs_from_app" {
  security_group_id = aws_security_group.file.id

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 2049
  ip_protocol                  = "tcp"
  to_port                      = 2049

  description = "Allow NFS from application servers"
}

# On-premises administration -> File server
resource "aws_vpc_security_group_ingress_rule" "file_ssh_from_onprem" {
  security_group_id = aws_security_group.file.id

  cidr_ipv4   = var.onprem_cidr
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22

  description = "Allow SSH from on-premises network over VPN"
}

# File server -> AWS APIs / software repositories
resource "aws_vpc_security_group_egress_rule" "file_https_outbound" {
  security_group_id = aws_security_group.file.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443

  description = "Allow HTTPS outbound through Regional NAT Gateway"
}


# ============================================================
# AWS DMS Security Group Rules
# ============================================================

# DMS -> Source on-premises MySQL database
resource "aws_vpc_security_group_egress_rule" "dms_mysql_to_source" {
  security_group_id = aws_security_group.dms.id

  cidr_ipv4   = "192.168.56.20/32"
  from_port   = 3306
  ip_protocol = "tcp"
  to_port     = 3306

  description = "Allow AWS DMS to source on-premises MySQL database"
}

# DMS -> Target RDS MySQL database
resource "aws_vpc_security_group_egress_rule" "dms_mysql_to_target" {
  security_group_id = aws_security_group.dms.id

  referenced_security_group_id = aws_security_group.db.id
  from_port                    = 3306
  ip_protocol                  = "tcp"
  to_port                      = 3306

  description = "Allow AWS DMS to target Amazon RDS MySQL"
}

resource "aws_vpc_security_group_egress_rule" "dms_https_outbound" {
  security_group_id = aws_security_group.dms.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443

  description = "Allow HTTPS outbound for AWS Secrets Manager access"
}

resource "aws_security_group" "mgn_replication" {
  name        = "aws-migration-project-mgn-replication"
  description = "Security group for AWS MGN replication servers"
  vpc_id      = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "aws-migration-project-mgn-replication"
  })
}

resource "aws_vpc_security_group_ingress_rule" "mgn_replication_from_onprem_app" {
  security_group_id = aws_security_group.mgn_replication.id

  description = "MGN replication traffic from on-premises application server"
  cidr_ipv4   = "192.168.56.10/32"
  from_port   = 1500
  to_port     = 1500
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "mgn_replication_https_outbound" {
  security_group_id = aws_security_group.mgn_replication.id

  description = "HTTPS access to AWS MGN service endpoints"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}


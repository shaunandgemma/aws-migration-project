resource "aws_dms_replication_instance" "migration" {
  replication_instance_id    = "${local.name_prefix}-dms"
  replication_instance_class = "dms.t3.small"

  allocated_storage = 20

  replication_subnet_group_id = aws_dms_replication_subnet_group.migration.id
  vpc_security_group_ids      = [aws_security_group.dms.id]

  publicly_accessible = false
  multi_az            = false

  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dms"
  })

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role
  ]
}

resource "aws_dms_replication_subnet_group" "migration" {
  replication_subnet_group_id          = "${local.name_prefix}-dms-subnet-group"
  replication_subnet_group_description = "Private subnets for AWS DMS replication instance"

  subnet_ids = [
    aws_subnet.app_private_a.id,
    aws_subnet.app_private_b.id
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-dms-subnet-group"
  })

  depends_on = [
    aws_iam_role_policy_attachment.dms_vpc_role,
    aws_iam_role_policy_attachment.dms_cloudwatch_logs_role

  ]
}

data "aws_secretsmanager_secret" "dms_source_mysql" {
  name = "aws-migration-project/dms/source-mysql"
}

resource "aws_dms_endpoint" "source_mysql" {
  endpoint_id   = "${local.name_prefix}-source-mysql"
  endpoint_type = "source"
  engine_name   = "mysql"

  secrets_manager_arn             = data.aws_secretsmanager_secret.dms_source_mysql.arn
  secrets_manager_access_role_arn = aws_iam_role.dms_secrets_role.arn

  ssl_mode        = "verify-ca"
  certificate_arn = aws_dms_certificate.source_mysql_ca.certificate_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-source-mysql"
  })

  depends_on = [
    aws_iam_role_policy.dms_source_secret,
    aws_vpc_security_group_egress_rule.dms_https_outbound
  ]
}

resource "aws_dms_certificate" "source_mysql_ca" {
  certificate_id  = "${local.name_prefix}-source-mysql-ca-v1"
  certificate_pem = file("${path.module}/certificates/onprem-mysql-ca.pem")

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-source-mysql-ca"
  })
}

resource "aws_dms_certificate" "target_rds_ca" {
  certificate_id  = "${local.name_prefix}-target-rds-ca"
  certificate_pem = file("${path.module}/certificates/eu-west-2-bundle.pem")

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-target-rds-ca"
  })
}

resource "aws_dms_endpoint" "target_mysql" {
  endpoint_id   = "${local.name_prefix}-target-mysql"
  endpoint_type = "target"
  engine_name   = "mysql"

  secrets_manager_arn             = data.aws_secretsmanager_secret.dms_target_mysql.arn
  secrets_manager_access_role_arn = aws_iam_role.dms_secrets_role.arn

  ssl_mode        = "verify-ca"
  certificate_arn = aws_dms_certificate.target_rds_ca.certificate_arn

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-target-mysql"
  })

  depends_on = [
    aws_iam_role_policy.dms_target_secret
  ]
}

resource "aws_dms_replication_task" "mysql_migration" {
  replication_task_id      = "${local.name_prefix}-mysql-migration"
  migration_type           = "full-load-and-cdc"
  replication_instance_arn = aws_dms_replication_instance.migration.replication_instance_arn
  source_endpoint_arn      = aws_dms_endpoint.source_mysql.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target_mysql.endpoint_arn

  # Create the task but do not start migrating yet.
  start_replication_task = false

  table_mappings = jsonencode({
    rules = [
      {
        rule-type   = "selection"
        rule-id     = "1"
        rule-name   = "include-legacy-app"
        rule-action = "include"

        object-locator = {
          schema-name = "legacy_app"
          table-name  = "%"
        }
      }
    ]
  })

  replication_task_settings = jsonencode({
    Logging = {
      EnableLogging = true
    }

    FullLoadSettings = {
      TargetTablePrepMode = "DROP_AND_CREATE"
    }
  })

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mysql-migration"
  })
}
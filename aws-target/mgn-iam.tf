data "aws_caller_identity" "mgn_current" {}

resource "aws_iam_role" "mgn_replication_server" {
  name = "AWSApplicationMigrationReplicationServerRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_conversion_server" {
  name = "AWSApplicationMigrationConversionServerRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_migration_hub" {
  name = "AWSApplicationMigrationMGHRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "mgn.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_launch_drs" {
  name = "AWSApplicationMigrationLaunchInstanceWithDrsRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_launch_ssm" {
  name = "AWSApplicationMigrationLaunchInstanceWithSsmRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_fsx_proxy" {
  name = "AWSApplicationMigrationFsxProxyRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "mgn.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_fsx_proxy_link" {
  name = "AWSApplicationMigrationFsxProxyLinkRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "mgn.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role" "mgn_agent" {
  name = "AWSApplicationMigrationAgentRole"
  path = "/service-role/"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"

      Principal = {
        Service = "mgn.amazonaws.com"
      }

      Action = [
        "sts:AssumeRole",
        "sts:SetSourceIdentity"
      ]

      Condition = {
        StringLike = {
          "sts:SourceIdentity" = "s-*"
          "aws:SourceAccount"  = data.aws_caller_identity.mgn_current.account_id
        }
      }
    }]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "mgn_replication_server" {
  role       = aws_iam_role.mgn_replication_server.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationReplicationServerPolicy"
}

resource "aws_iam_role_policy_attachment" "mgn_conversion_server" {
  role       = aws_iam_role.mgn_conversion_server.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationConversionServerPolicy"
}

resource "aws_iam_role_policy_attachment" "mgn_migration_hub" {
  role       = aws_iam_role.mgn_migration_hub.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationMGHAccess"
}

resource "aws_iam_role_policy_attachment" "mgn_launch_drs_ssm" {
  role       = aws_iam_role.mgn_launch_drs.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "mgn_launch_drs_agent" {
  role       = aws_iam_role.mgn_launch_drs.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSElasticDisasterRecoveryEc2InstancePolicy"
}

resource "aws_iam_role_policy_attachment" "mgn_launch_ssm" {
  role       = aws_iam_role.mgn_launch_ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "mgn_fsx_proxy" {
  role       = aws_iam_role.mgn_fsx_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationFSxProxyPolicy"
}

resource "aws_iam_role_policy_attachment" "mgn_fsx_proxy_link" {
  role       = aws_iam_role.mgn_fsx_proxy_link.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationFSxProxyVPCPolicy"
}

resource "aws_iam_role_policy_attachment" "mgn_agent" {
  role       = aws_iam_role.mgn_agent.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSApplicationMigrationAgentPolicy_v2"
}
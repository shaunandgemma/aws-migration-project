resource "aws_db_subnet_group" "mysql" {
  name = "${local.name_prefix}-mysql-subnet-group"

  subnet_ids = [
    aws_subnet.db_private_a.id,
    aws_subnet.db_private_b.id
  ]

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mysql-subnet-group"
  })
}

resource "aws_db_instance" "mysql" {
  identifier = "${local.name_prefix}-mysql"

  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = "legacy_app"
  username = "appadmin"

  manage_master_user_password = true

  multi_az            = true
  publicly_accessible = false

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = 7

  deletion_protection = false
  skip_final_snapshot = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-mysql"
  })
}
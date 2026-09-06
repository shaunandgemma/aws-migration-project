resource "aws_vpc" "migration" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

resource "aws_subnet" "app_private_a" {
  vpc_id                  = aws_vpc.migration.id
  cidr_block              = var.app_private_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-private-a"
    Tier = "application"
  })
}

resource "aws_subnet" "app_private_b" {
  vpc_id                  = aws_vpc.migration.id
  cidr_block              = var.app_private_b_cidr
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-private-b"
    Tier = "application"
  })
}

resource "aws_subnet" "db_private_a" {
  vpc_id                  = aws_vpc.migration.id
  cidr_block              = var.db_private_a_cidr
  availability_zone       = var.availability_zone_a
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-private-a"
    Tier = "database"
  })
}

resource "aws_subnet" "db_private_b" {
  vpc_id                  = aws_vpc.migration.id
  cidr_block              = var.db_private_b_cidr
  availability_zone       = var.availability_zone_b
  map_public_ip_on_launch = false

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-private-b"
    Tier = "database"
  })
}

resource "aws_internet_gateway" "migration" {
  vpc_id = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

resource "aws_nat_gateway" "regional" {
  vpc_id            = aws_vpc.migration.id
  availability_mode = "regional"
  connectivity_type = "public"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-regional-nat"
  })

  depends_on = [aws_internet_gateway.migration]
}

resource "aws_route_table" "app_private_a" {
  vpc_id = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-private-a-rt"
  })
}

resource "aws_route_table" "app_private_b" {
  vpc_id = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-app-private-b-rt"
  })
}

resource "aws_route" "app_private_a_nat" {
  route_table_id         = aws_route_table.app_private_a.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.regional.id
}

resource "aws_route" "app_private_b_nat" {
  route_table_id         = aws_route_table.app_private_b.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.regional.id
}

resource "aws_route_table" "db_private" {
  vpc_id = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-db-private-rt"
  })
}

resource "aws_route_table_association" "app_private_a" {
  subnet_id      = aws_subnet.app_private_a.id
  route_table_id = aws_route_table.app_private_a.id
}

resource "aws_route_table_association" "app_private_b" {
  subnet_id      = aws_subnet.app_private_b.id
  route_table_id = aws_route_table.app_private_b.id
}

resource "aws_route_table_association" "db_private_a" {
  subnet_id      = aws_subnet.db_private_a.id
  route_table_id = aws_route_table.db_private.id
}

resource "aws_route_table_association" "db_private_b" {
  subnet_id      = aws_subnet.db_private_b.id
  route_table_id = aws_route_table.db_private.id
}

resource "aws_vpn_gateway" "migration" {
  vpc_id = aws_vpc.migration.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vgw"
  })
}

resource "aws_customer_gateway" "onprem" {
  bgp_asn    = var.customer_gateway_bgp_asn
  ip_address = var.customer_gateway_ip
  type       = "ipsec.1"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-customer-gateway"
  })
}

resource "aws_vpn_connection" "onprem" {
  customer_gateway_id = aws_customer_gateway.onprem.id
  vpn_gateway_id      = aws_vpn_gateway.migration.id
  type                = "ipsec.1"
  static_routes_only  = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-site-to-site-vpn"
  })
}

resource "aws_vpn_connection_route" "onprem" {
  vpn_connection_id      = aws_vpn_connection.onprem.id
  destination_cidr_block = var.onprem_cidr
}

resource "aws_route" "app_private_a_onprem" {
  route_table_id         = aws_route_table.app_private_a.id
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.migration.id
}

resource "aws_route" "app_private_b_onprem" {
  route_table_id         = aws_route_table.app_private_b.id
  destination_cidr_block = var.onprem_cidr
  gateway_id             = aws_vpn_gateway.migration.id
}

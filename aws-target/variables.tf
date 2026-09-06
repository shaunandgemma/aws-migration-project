variable "aws_region" {
  description = "AWS Region used for the migration environment"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Name prefix used for AWS migration resources"
  type        = string
  default     = "aws-migration-project"
}

variable "vpc_cidr" {
  description = "CIDR block for the AWS migration VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "app_private_a_cidr" {
  description = "CIDR block for the application private subnet in eu-west-2a"
  type        = string
  default     = "10.20.1.0/24"
}

variable "app_private_b_cidr" {
  description = "CIDR block for the application private subnet in eu-west-2b"
  type        = string
  default     = "10.20.2.0/24"
}

variable "db_private_a_cidr" {
  description = "CIDR block for the database private subnet in eu-west-2a"
  type        = string
  default     = "10.20.3.0/24"
}

variable "db_private_b_cidr" {
  description = "CIDR block for the database private subnet in eu-west-2b"
  type        = string
  default     = "10.20.4.0/24"
}

variable "availability_zone_a" {
  description = "First Availability Zone"
  type        = string
  default     = "eu-west-2a"
}

variable "availability_zone_b" {
  description = "Second Availability Zone"
  type        = string
  default     = "eu-west-2b"
}

variable "onprem_cidr" {
  description = "On-premises network CIDR used for migration connectivity"
  type        = string
  default     = "192.168.56.0/24"
}

variable "customer_gateway_ip" {
  description = "Public IPv4 address of the customer-side VPN gateway"
  type        = string
}

variable "customer_gateway_bgp_asn" {
  description = "Private BGP ASN assigned to the customer gateway"
  type        = number
  default     = 65000
}

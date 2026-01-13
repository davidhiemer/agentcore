variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID (created externally)"
  type        = string
}

variable "private_subnet_ids" {
  description = "Map of private subnet configurations"
  type = map(object({
    subnet_id         = string
    availability_zone = string
    cidr_block        = string
  }))
}

variable "public_subnet_ids" {
  description = "Map of public subnet IDs by AZ (for NAT gateway placement)"
  type        = map(string)
  default     = {}
}

variable "security_group_ids" {
  description = "Security group IDs for various purposes"
  type = object({
    agentcore_runtime  = string
    vpc_endpoints      = string
    nat_gateway_egress = string
  })
}

variable "route_table_ids" {
  description = "Route table IDs by AZ"
  type        = map(string)
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "subnets_by_az" {
  description = "Map of AZ to subnet ID"
  type        = map(string)
}

variable "vpc_endpoint_subnet_ids" {
  description = "Subnet IDs for VPC endpoints (AZ-limited)"
  type        = list(string)
}

variable "nat_mode" {
  description = "NAT gateway mode: per_az or single"
  type        = string
}

variable "nat_gateway_azs" {
  description = "AZs to deploy NAT gateways in"
  type        = list(string)
}

variable "gateway_endpoints" {
  description = "Set of gateway endpoint services"
  type        = set(string)
}

variable "interface_endpoints" {
  description = "Set of interface endpoint services"
  type        = set(string)
}

variable "cross_account_access" {
  description = "Cross-account access configuration"
  type = object({
    enabled                 = bool
    allowed_caller_accounts = set(string)
    allowed_caller_roles    = map(set(string))
    allowed_caller_vpc_ids  = set(string)
  })
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


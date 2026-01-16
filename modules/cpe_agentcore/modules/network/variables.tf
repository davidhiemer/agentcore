# ==============================================================================
# NETWORK SUBMODULE VARIABLES
# Creates all networking resources within the provided VPC
# ==============================================================================

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

# ==============================================================================
# VPC CONFIGURATION (VPC created externally)
# ==============================================================================

variable "vpc_id" {
  description = "VPC ID (created externally)"
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR block for subnet calculations"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones to deploy resources across"
  type        = list(string)
}

variable "internet_gateway_id" {
  description = "Optional existing Internet Gateway ID. If null, module creates one"
  type        = string
  default     = null
}

# ==============================================================================
# SUBNET CONFIGURATION
# ==============================================================================

variable "subnet_config" {
  description = "Subnet configuration for CIDR calculations"
  type = object({
    # Number of bits to add to VPC CIDR for subnet calculation
    # e.g., if VPC is /16, newbits=8 creates /24 subnets
    private_subnet_newbits = number
    public_subnet_newbits  = number

    # Starting netnum for each subnet type
    # Choose values that don't conflict with existing subnets
    private_subnet_start_netnum = number
    public_subnet_start_netnum  = number
  })

  default = {
    private_subnet_newbits      = 4  # /16 VPC -> /20 subnets (4096 IPs each)
    public_subnet_newbits       = 6  # /16 VPC -> /22 subnets (1024 IPs each)
    private_subnet_start_netnum = 8  # 10.x.128.0/20, 10.x.144.0/20, 10.x.160.0/20
    public_subnet_start_netnum  = 56 # 10.x.224.0/22, 10.x.228.0/22, 10.x.232.0/22
  }
}

# ==============================================================================
# NAT CONFIGURATION
# ==============================================================================

variable "nat_mode" {
  description = "NAT gateway mode: per_az (HA) or single (cost-optimized)"
  type        = string

  validation {
    condition     = contains(["per_az", "single"], var.nat_mode)
    error_message = "NAT mode must be 'per_az' or 'single'."
  }
}

# ==============================================================================
# VPC ENDPOINTS CONFIGURATION
# ==============================================================================

variable "vpc_endpoint_az_count" {
  description = "Number of AZs to deploy interface VPC endpoints across"
  type        = number
  default     = 2
}

variable "gateway_endpoints" {
  description = "Set of gateway endpoint services (S3, DynamoDB)"
  type        = set(string)
}

variable "interface_endpoints" {
  description = "Set of interface endpoint services"
  type        = set(string)
}

# ==============================================================================
# CROSS-ACCOUNT ACCESS
# ==============================================================================

variable "cross_account_access" {
  description = "Cross-account access configuration"
  type = object({
    enabled                 = bool
    allowed_caller_accounts = set(string)
    allowed_caller_roles    = map(set(string))
    allowed_caller_vpc_ids  = set(string)
  })
}

# ==============================================================================
# TAGS
# ==============================================================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

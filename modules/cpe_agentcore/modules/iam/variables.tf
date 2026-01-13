variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "aws_account_id" {
  description = "AWS account ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "agents" {
  description = "Normalized agent configurations"
  type = map(object({
    name               = string
    description        = string
    capability_bundles = set(string)
    custom_policy_arns = optional(set(string), [])
    effective_tags     = map(string)
  }))
}

variable "permission_boundary_name" {
  description = "Name for the permission boundary policy"
  type        = string
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

variable "vpc_endpoint_arns" {
  description = "ARNs of VPC endpoints (from network module)"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


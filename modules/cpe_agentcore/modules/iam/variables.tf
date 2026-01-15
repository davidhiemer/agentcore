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
    name                   = string
    description            = string
    container_image_digest = string
    mode                   = string
    effective_memory_mb    = number
    effective_timeout_seconds = number
    effective_concurrency  = number
    capability_bundles     = set(string)
    custom_policy_arns     = set(string)
    memory_enabled         = bool
    gateway_enabled        = bool
    tools_enabled          = bool
    effective_tags         = map(string)
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

variable "memory_enabled" {
  description = "Whether AgentCore Memory is enabled"
  type        = bool
  default     = false
}

variable "gateway_enabled" {
  description = "Whether AgentCore Gateway is enabled"
  type        = bool
  default     = false
}

variable "tools_enabled" {
  description = "Whether AgentCore Tools are enabled"
  type        = bool
  default     = false
}

variable "vpc_endpoint_arns" {
  description = "ARNs of VPC endpoints (from network module)"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

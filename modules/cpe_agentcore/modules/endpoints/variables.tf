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

variable "agents" {
  description = "Normalized agent configurations"
  type = map(object({
    name                      = string
    description               = string
    container_image_digest    = string
    mode                      = string
    effective_memory_mb       = number
    effective_timeout_seconds = number
    effective_concurrency     = number
    capability_bundles        = set(string)
    custom_policy_arns        = set(string)
    memory_enabled            = bool
    gateway_enabled           = bool
    tools_enabled             = bool
    effective_tags            = map(string)
  }))
}

variable "runtime_arns" {
  description = "Map of agent key to runtime ARN (from runtime module)"
  type        = map(string)
}

variable "runtime_ids" {
  description = "Map of agent key to runtime ID (from runtime module)"
  type        = map(string)
}

variable "endpoint_arns" {
  description = "Map of agent key to endpoint ARN (from runtime module)"
  type        = map(string)
}

variable "endpoint_urls" {
  description = "Map of agent key to endpoint URL (from runtime module)"
  type        = map(string)
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

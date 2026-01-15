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

variable "gateway_config" {
  description = "Gateway configuration"
  type = object({
    tool_policies = map(object({
      tool_name      = string
      allowed_agents = set(string)
      rate_limit = object({
        requests_per_minute = number
        burst_limit         = number
      })
      timeout_seconds = number
    }))

    connections = map(object({
      name         = string
      endpoint_url = string
      auth_type    = string
      secret_arn   = optional(string)
    }))
  })
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

variable "vpc_id" {
  description = "VPC ID for VPC link"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC attachment"
  type        = list(string)
}

variable "execution_role_arns" {
  description = "Map of agent key to execution role ARN"
  type        = map(string)
}

variable "runtime_ids" {
  description = "Map of agent key to runtime ID"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

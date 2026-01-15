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

variable "tools_config" {
  description = "Tools configuration"
  type = object({
    code_interpreter = object({
      enabled               = bool
      languages             = set(string)
      max_execution_seconds = number
      memory_mb             = number
      allow_network         = bool
    })

    browser_tool = object({
      enabled            = bool
      allowed_domains    = set(string)
      blocked_domains    = set(string)
      max_page_size_mb   = number
      screenshot_enabled = bool
    })
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
  description = "VPC ID for VPC attachment"
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

variable "gateway_arn" {
  description = "ARN of the Gateway (for tool invocation)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


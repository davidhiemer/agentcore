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

variable "vpc_id" {
  description = "VPC ID for attachment"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for VPC attachment"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for runtime"
  type        = string
}

variable "ecr_repository_urls" {
  description = "Map of agent key to ECR repository URL"
  type        = map(string)
}

variable "execution_role_arns" {
  description = "Map of agent key to execution role ARN"
  type        = map(string)
}

variable "identity_provider_arn" {
  description = "ARN of the identity provider (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}

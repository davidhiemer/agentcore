variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "agents" {
  description = "Normalized agent configurations"
  type = map(object({
    name                   = string
    description            = string
    runtime_version_digest = string
    effective_tags         = map(string)
  }))
}

variable "runtime_arns" {
  description = "Map of agent key to runtime ARN"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


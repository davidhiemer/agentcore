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
    name           = string
    description    = string
    effective_tags = map(string)
  }))
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



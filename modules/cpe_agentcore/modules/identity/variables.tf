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

variable "identity_config" {
  description = "Identity provider configuration"
  type = object({
    enabled = bool

    provider = object({
      type = string # "cognito", "entra_id", "okta", "saml"

      # Cognito-specific
      user_pool_id     = optional(string)
      user_pool_client = optional(string)

      # OIDC-specific (Entra, Okta)
      issuer_url        = optional(string)
      client_id         = optional(string)
      client_secret_arn = optional(string)

      # SAML-specific
      metadata_url = optional(string)
    })

    role_mappings = map(object({
      claim_name  = string
      claim_value = string
      agent_keys  = set(string)
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

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


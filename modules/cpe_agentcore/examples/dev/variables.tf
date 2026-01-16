# Variables inherited from root module - see ../../variables.tf for full definitions

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "vpc_config" {
  description = "VPC configuration - VPC provided externally, networking created by module"
  type = object({
    vpc_id              = string
    vpc_cidr            = string
    availability_zones  = list(string)
    internet_gateway_id = optional(string, null)
  })
}

variable "scale_profile" {
  description = "Environment-specific scaling configuration"
  type = object({
    # Network scaling
    nat_mode              = string
    vpc_endpoint_az_count = number

    # Runtime scaling
    runtime_concurrency_limit       = number
    runtime_memory_mb_default       = number
    runtime_timeout_seconds_default = number

    # Memory scaling
    memory_session_ttl_hours        = number
    memory_long_term_retention_days = number

    # Gateway scaling
    gateway_rate_limit_default  = number
    gateway_burst_limit_default = number

    # Tools scaling
    code_interpreter_max_execution_seconds = number
    code_interpreter_memory_mb             = number
    browser_max_page_size_mb               = number

    # Observability scaling
    log_retention_days         = number
    metrics_resolution_seconds = number
    alarm_evaluation_periods   = number
    xray_sampling_rate         = number

    # Feature flags
    enable_memory   = bool
    enable_identity = bool
    enable_gateway  = bool
    enable_tools    = bool
  })
}

variable "agents" {
  description = "Map of agent configurations"
  type = map(object({
    name                   = string
    description            = string
    container_image_digest = string
    mode                   = optional(string, "realtime")
    timeout_seconds        = optional(number)
    memory_mb              = optional(number)
    concurrency            = optional(number)
    capability_bundles     = set(string)
    custom_policy_arns     = optional(set(string), [])
    memory_enabled         = optional(bool, true)
    gateway_enabled        = optional(bool, true)
    tools_enabled          = optional(bool, false)
    additional_tags        = optional(map(string), {})
  }))
}

variable "memory_config" {
  description = "Memory configuration"
  type = object({
    session_memory = object({
      enabled            = bool
      max_context_tokens = optional(number, 100000)
    })
    long_term_memory = object({
      enabled            = bool
      encryption_key_arn = optional(string)
    })
  })
  default = {
    session_memory = {
      enabled            = true
      max_context_tokens = 100000
    }
    long_term_memory = {
      enabled            = true
      encryption_key_arn = null
    }
  }
}

variable "identity_config" {
  description = "Identity configuration"
  type = object({
    enabled = bool
    provider = optional(object({
      type              = string
      user_pool_id      = optional(string)
      user_pool_client  = optional(string)
      issuer_url        = optional(string)
      client_id         = optional(string)
      client_secret_arn = optional(string)
      metadata_url      = optional(string)
    }))
    role_mappings = optional(map(object({
      claim_name  = string
      claim_value = string
      agent_keys  = set(string)
    })), {})
  })
  default = {
    enabled       = false
    provider      = null
    role_mappings = {}
  }
}

variable "gateway_config" {
  description = "Gateway configuration"
  type = object({
    tool_policies = optional(map(object({
      tool_name      = string
      allowed_agents = set(string)
      rate_limit = optional(object({
        requests_per_minute = number
        burst_limit         = number
      }))
      timeout_seconds = optional(number, 30)
    })), {})
    connections = optional(map(object({
      name         = string
      endpoint_url = string
      auth_type    = string
      secret_arn   = optional(string)
    })), {})
  })
  default = {
    tool_policies = {}
    connections   = {}
  }
}

variable "tools_config" {
  description = "Tools configuration"
  type = object({
    code_interpreter = object({
      enabled       = bool
      languages     = optional(set(string), ["python"])
      allow_network = optional(bool, false)
    })
    browser_tool = object({
      enabled            = bool
      allowed_domains    = optional(set(string), [])
      blocked_domains    = optional(set(string), [])
      screenshot_enabled = optional(bool, true)
    })
  })
  default = {
    code_interpreter = {
      enabled       = false
      languages     = ["python"]
      allow_network = false
    }
    browser_tool = {
      enabled            = false
      allowed_domains    = []
      blocked_domains    = []
      screenshot_enabled = true
    }
  }
}

variable "cross_account_access" {
  description = "Cross-account access configuration"
  type = object({
    enabled                 = bool
    allowed_caller_accounts = set(string)
    allowed_caller_roles    = map(set(string))
    allowed_caller_vpc_ids  = optional(set(string), [])
  })
  default = {
    enabled                 = false
    allowed_caller_accounts = []
    allowed_caller_roles    = {}
    allowed_caller_vpc_ids  = []
  }
}

variable "observability_config" {
  description = "Observability configuration"
  type = object({
    splunk_enabled              = optional(bool, false)
    splunk_hec_endpoint         = optional(string, "")
    splunk_hec_token_secret_arn = optional(string, "")
    alarm_sns_topic_arn         = string
    enable_xray_tracing         = bool
    dashboard_enabled           = bool
  })
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

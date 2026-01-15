# ==============================================================================
# ENVIRONMENT IDENTIFICATION
# ==============================================================================

variable "environment" {
  description = "Environment identifier (dev, preprod, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "preprod", "prod"], var.environment)
    error_message = "Environment must be one of: dev, preprod, prod."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]$", var.aws_region))
    error_message = "AWS region must be a valid region identifier (e.g., us-east-1)."
  }
}

variable "aws_account_id" {
  description = "AWS account ID for deployment"
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "AWS account ID must be a 12-digit number."
  }
}

# ==============================================================================
# VPC INPUTS (Created externally)
# ==============================================================================

variable "vpc_config" {
  description = "VPC configuration - VPC is created outside this module"
  type = object({
    vpc_id = string
    private_subnet_ids = map(object({
      subnet_id         = string
      availability_zone = string
      cidr_block        = string
    }))
    public_subnet_ids = optional(map(string), {})
    security_group_ids = object({
      agentcore_runtime  = string
      vpc_endpoints      = string
      nat_gateway_egress = string
    })
    route_table_ids = map(string)
  })

  validation {
    condition     = can(regex("^vpc-[a-f0-9]+$", var.vpc_config.vpc_id))
    error_message = "VPC ID must be a valid VPC identifier."
  }

  validation {
    condition     = length(var.vpc_config.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets across different AZs are required."
  }
}

# ==============================================================================
# SCALE PROFILE (All environment differences expressed here)
# ==============================================================================

variable "scale_profile" {
  description = "Environment-specific scaling configuration for all AgentCore components"
  type = object({
    # Network scaling
    nat_mode              = string # "per_az" or "single"
    vpc_endpoint_az_count = number # 1-3

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
    xray_sampling_rate         = number # 0.0-1.0

    # Feature flags
    enable_memory   = bool
    enable_identity = bool
    enable_gateway  = bool
    enable_tools    = bool
  })

  # Network validations
  validation {
    condition     = contains(["per_az", "single"], var.scale_profile.nat_mode)
    error_message = "NAT mode must be 'per_az' or 'single'."
  }

  validation {
    condition     = var.scale_profile.vpc_endpoint_az_count >= 1 && var.scale_profile.vpc_endpoint_az_count <= 3
    error_message = "VPC endpoint AZ count must be between 1 and 3."
  }

  # Runtime validations
  validation {
    condition     = var.scale_profile.runtime_concurrency_limit >= 1 && var.scale_profile.runtime_concurrency_limit <= 10000
    error_message = "Runtime concurrency limit must be between 1 and 10000."
  }

  validation {
    condition     = var.scale_profile.runtime_memory_mb_default >= 512 && var.scale_profile.runtime_memory_mb_default <= 10240
    error_message = "Runtime memory must be between 512 and 10240 MB."
  }

  validation {
    condition     = var.scale_profile.runtime_memory_mb_default % 64 == 0
    error_message = "Runtime memory must be a multiple of 64 MB."
  }

  validation {
    condition     = var.scale_profile.runtime_timeout_seconds_default >= 1 && var.scale_profile.runtime_timeout_seconds_default <= 28800
    error_message = "Runtime timeout must be between 1 and 28800 seconds (8 hours for async)."
  }

  # Memory validations
  validation {
    condition     = var.scale_profile.memory_session_ttl_hours >= 1 && var.scale_profile.memory_session_ttl_hours <= 168
    error_message = "Memory session TTL must be between 1 and 168 hours (1 week)."
  }

  validation {
    condition     = var.scale_profile.memory_long_term_retention_days >= 30 && var.scale_profile.memory_long_term_retention_days <= 365
    error_message = "Memory long-term retention must be between 30 and 365 days."
  }

  # Gateway validations
  validation {
    condition     = var.scale_profile.gateway_rate_limit_default >= 1 && var.scale_profile.gateway_rate_limit_default <= 10000
    error_message = "Gateway rate limit must be between 1 and 10000 requests per minute."
  }

  validation {
    condition     = var.scale_profile.gateway_burst_limit_default >= 1 && var.scale_profile.gateway_burst_limit_default <= 5000
    error_message = "Gateway burst limit must be between 1 and 5000."
  }

  # Tools validations
  validation {
    condition     = var.scale_profile.code_interpreter_max_execution_seconds >= 1 && var.scale_profile.code_interpreter_max_execution_seconds <= 300
    error_message = "Code interpreter max execution must be between 1 and 300 seconds."
  }

  validation {
    condition     = var.scale_profile.code_interpreter_memory_mb >= 128 && var.scale_profile.code_interpreter_memory_mb <= 4096
    error_message = "Code interpreter memory must be between 128 and 4096 MB."
  }

  validation {
    condition     = var.scale_profile.browser_max_page_size_mb >= 1 && var.scale_profile.browser_max_page_size_mb <= 50
    error_message = "Browser max page size must be between 1 and 50 MB."
  }

  # Observability validations
  validation {
    condition     = var.scale_profile.log_retention_days >= 30
    error_message = "Log retention must be at least 30 days for audit requirements."
  }

  validation {
    condition = contains(
      [30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.scale_profile.log_retention_days
    )
    error_message = "Log retention must be a valid CloudWatch Logs retention value."
  }

  validation {
    condition     = contains([1, 60], var.scale_profile.metrics_resolution_seconds)
    error_message = "Metrics resolution must be 1 (high resolution) or 60 (standard)."
  }

  validation {
    condition     = var.scale_profile.alarm_evaluation_periods >= 1 && var.scale_profile.alarm_evaluation_periods <= 24
    error_message = "Alarm evaluation periods must be between 1 and 24."
  }

  validation {
    condition     = var.scale_profile.xray_sampling_rate >= 0 && var.scale_profile.xray_sampling_rate <= 1
    error_message = "X-Ray sampling rate must be between 0.0 and 1.0."
  }
}

# ==============================================================================
# AGENT DEFINITIONS
# ==============================================================================

variable "agents" {
  description = "Map of agent configurations to deploy"
  type = map(object({
    name        = string
    description = string

    # Container configuration
    container_image_digest = string # sha256:... from ECR

    # Runtime configuration
    mode            = optional(string, "realtime") # "realtime" or "async"
    timeout_seconds = optional(number)             # Override default
    memory_mb       = optional(number)             # Override default
    concurrency     = optional(number)             # Per-agent concurrency limit

    # IAM capability bundles
    capability_bundles = set(string)

    # Custom IAM policies (optional)
    custom_policy_arns = optional(set(string), [])

    # Feature integration
    memory_enabled  = optional(bool, true)
    gateway_enabled = optional(bool, true)
    tools_enabled   = optional(bool, false)

    # Tags specific to this agent
    additional_tags = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.agents : can(regex("^sha256:[a-f0-9]{64}$", v.container_image_digest))
    ])
    error_message = "All agent container_image_digest values must be valid SHA256 digests."
  }

  validation {
    condition = alltrue([
      for k, v in var.agents : contains(["realtime", "async"], v.mode)
    ])
    error_message = "Agent mode must be 'realtime' or 'async'."
  }

  validation {
    condition = alltrue([
      for k, v in var.agents : v.mode == "realtime" ? (v.timeout_seconds == null || v.timeout_seconds <= 300) : true
    ])
    error_message = "Realtime agents must have timeout <= 300 seconds."
  }

  validation {
    condition = alltrue([
      for k, v in var.agents : v.mode == "async" ? (v.timeout_seconds == null || v.timeout_seconds <= 28800) : true
    ])
    error_message = "Async agents must have timeout <= 28800 seconds (8 hours)."
  }

  validation {
    condition = alltrue([
      for k, v in var.agents : alltrue([
        for bundle in v.capability_bundles : contains([
          "baseline",
          "s3_readonly",
          "s3_readwrite",
          "dynamodb_readonly",
          "dynamodb_readwrite",
          "secrets_readonly",
          "ssm_parameters_readonly",
          "kms_encrypt_decrypt",
          "sns_publish",
          "sqs_send_receive",
          "lambda_invoke",
          "bedrock_invoke_model",
          "agentcore_memory",
          "agentcore_gateway",
          "agentcore_tools"
        ], bundle)
      ])
    ])
    error_message = "Invalid capability bundle specified. Check allowed bundles."
  }
}

# ==============================================================================
# MEMORY CONFIGURATION
# ==============================================================================

variable "memory_config" {
  description = "AgentCore Memory configuration"
  type = object({
    session_memory = object({
      enabled            = bool
      max_context_tokens = optional(number, 100000)
    })

    long_term_memory = object({
      enabled            = bool
      encryption_key_arn = optional(string) # KMS key ARN, null = AWS managed
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

  validation {
    condition     = var.memory_config.session_memory.max_context_tokens >= 1000 && var.memory_config.session_memory.max_context_tokens <= 200000
    error_message = "Max context tokens must be between 1000 and 200000."
  }
}

# ==============================================================================
# IDENTITY CONFIGURATION
# ==============================================================================

variable "identity_config" {
  description = "AgentCore Identity configuration for IdP integration"
  type = object({
    enabled = bool

    provider = optional(object({
      type = string # "cognito", "entra_id", "okta", "saml"

      # Cognito-specific
      user_pool_id     = optional(string)
      user_pool_client = optional(string)

      # OIDC-specific (Entra, Okta)
      issuer_url        = optional(string)
      client_id         = optional(string)
      client_secret_arn = optional(string) # Secrets Manager ARN

      # SAML-specific
      metadata_url = optional(string)
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

  validation {
    condition = var.identity_config.enabled == false || (
      var.identity_config.provider != null &&
      contains(["cognito", "entra_id", "okta", "saml"], var.identity_config.provider.type)
    )
    error_message = "When identity is enabled, provider type must be one of: cognito, entra_id, okta, saml."
  }
}

# ==============================================================================
# GATEWAY CONFIGURATION
# ==============================================================================

variable "gateway_config" {
  description = "AgentCore Gateway configuration for tool governance"
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
      auth_type    = string # "api_key", "oauth", "iam", "none"
      secret_arn   = optional(string)
    })), {})
  })

  default = {
    tool_policies = {}
    connections   = {}
  }

  validation {
    condition = alltrue([
      for k, v in var.gateway_config.connections : contains(["api_key", "oauth", "iam", "none"], v.auth_type)
    ])
    error_message = "Connection auth_type must be one of: api_key, oauth, iam, none."
  }
}

# ==============================================================================
# TOOLS CONFIGURATION
# ==============================================================================

variable "tools_config" {
  description = "AgentCore Tools configuration (Code Interpreter, Browser Tool)"
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

  validation {
    condition = alltrue([
      for lang in var.tools_config.code_interpreter.languages : contains(["python", "nodejs", "bash"], lang)
    ])
    error_message = "Code interpreter languages must be one of: python, nodejs, bash."
  }
}

# ==============================================================================
# CROSS-ACCOUNT ACCESS
# ==============================================================================

variable "cross_account_access" {
  description = "Configuration for cross-account invocation"
  type = object({
    enabled                 = bool
    allowed_caller_accounts = set(string)
    allowed_caller_roles    = map(set(string)) # account_id -> role ARNs
    allowed_caller_vpc_ids  = optional(set(string), [])
  })

  default = {
    enabled                 = false
    allowed_caller_accounts = []
    allowed_caller_roles    = {}
    allowed_caller_vpc_ids  = []
  }

  validation {
    condition = alltrue([
      for account in var.cross_account_access.allowed_caller_accounts : can(regex("^[0-9]{12}$", account))
    ])
    error_message = "All caller account IDs must be valid 12-digit AWS account IDs."
  }
}

# ==============================================================================
# OBSERVABILITY CONFIGURATION
# ==============================================================================

variable "observability_config" {
  description = "Observability and monitoring configuration"
  type = object({
    splunk_hec_endpoint         = string
    splunk_hec_token_secret_arn = string
    alarm_sns_topic_arn         = string
    enable_xray_tracing         = bool
    dashboard_enabled           = bool
  })

  validation {
    condition     = can(regex("^https://", var.observability_config.splunk_hec_endpoint))
    error_message = "Splunk HEC endpoint must be an HTTPS URL."
  }

  validation {
    condition     = can(regex("^arn:aws:secretsmanager:", var.observability_config.splunk_hec_token_secret_arn))
    error_message = "Splunk HEC token must be stored in Secrets Manager."
  }

  validation {
    condition     = can(regex("^arn:aws:sns:", var.observability_config.alarm_sns_topic_arn))
    error_message = "Alarm SNS topic must be a valid SNS ARN."
  }
}

# ==============================================================================
# TAGGING
# ==============================================================================

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for k, v in var.tags : can(regex("^[a-zA-Z0-9_.:/=+\\-@]+$", k))
    ])
    error_message = "Tag keys must contain only valid AWS tag characters."
  }
}

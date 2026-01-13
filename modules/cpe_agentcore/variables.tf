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
  description = "Environment-specific scaling configuration"
  type = object({
    # Network scaling
    nat_mode              = string
    vpc_endpoint_az_count = number

    # Runtime scaling
    runtime_concurrency_limit = number
    runtime_memory_mb         = number
    runtime_timeout_seconds   = number

    # Observability scaling
    log_retention_days         = number
    metrics_resolution_seconds = number
    alarm_evaluation_periods   = number

    # Tool execution scaling
    tool_execution_timeout_seconds = number
    tool_max_concurrent_executions = number

    # Feature flags for future capabilities
    enable_gateway = bool
    enable_memory  = bool
  })

  validation {
    condition     = contains(["per_az", "single"], var.scale_profile.nat_mode)
    error_message = "NAT mode must be 'per_az' or 'single'."
  }

  validation {
    condition     = var.scale_profile.vpc_endpoint_az_count >= 1 && var.scale_profile.vpc_endpoint_az_count <= 3
    error_message = "VPC endpoint AZ count must be between 1 and 3."
  }

  validation {
    condition     = var.scale_profile.runtime_concurrency_limit >= 1 && var.scale_profile.runtime_concurrency_limit <= 10000
    error_message = "Runtime concurrency limit must be between 1 and 10000."
  }

  validation {
    condition     = var.scale_profile.runtime_memory_mb >= 128 && var.scale_profile.runtime_memory_mb <= 10240
    error_message = "Runtime memory must be between 128 and 10240 MB."
  }

  validation {
    condition     = var.scale_profile.runtime_memory_mb % 64 == 0
    error_message = "Runtime memory must be a multiple of 64 MB."
  }

  validation {
    condition     = var.scale_profile.runtime_timeout_seconds >= 1 && var.scale_profile.runtime_timeout_seconds <= 900
    error_message = "Runtime timeout must be between 1 and 900 seconds."
  }

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
    condition     = var.scale_profile.tool_execution_timeout_seconds >= 1 && var.scale_profile.tool_execution_timeout_seconds <= 300
    error_message = "Tool execution timeout must be between 1 and 300 seconds."
  }

  validation {
    condition     = var.scale_profile.tool_max_concurrent_executions >= 1 && var.scale_profile.tool_max_concurrent_executions <= 100
    error_message = "Tool max concurrent executions must be between 1 and 100."
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

    # Runtime configuration
    runtime_version_digest = string

    # IAM capability bundles
    capability_bundles = set(string)

    # Custom IAM policies (optional)
    custom_policy_arns = optional(set(string), [])

    # Resource limits (optional overrides)
    memory_mb_override       = optional(number)
    timeout_seconds_override = optional(number)

    # Tags specific to this agent
    additional_tags = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.agents : can(regex("^sha256:[a-f0-9]{64}$", v.runtime_version_digest))
    ])
    error_message = "All agent runtime_version_digest values must be valid SHA256 digests."
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
          "bedrock_invoke_model"
        ], bundle)
      ])
    ])
    error_message = "Invalid capability bundle specified. Check allowed bundles."
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
    allowed_caller_roles    = map(set(string))
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


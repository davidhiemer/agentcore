locals {
  # ==============================================================================
  # NAMING CONVENTIONS
  # ==============================================================================
  name_prefix = "agentcore-v2-${var.environment}"

  # ==============================================================================
  # COMMON TAGS (Applied to all resources)
  # ==============================================================================
  common_tags = merge(
    {
      Environment        = var.environment
      Project            = "agentcore"
      ManagedBy          = "terraform"
      Module             = "cpe_agentcore"
      CostCenter         = "platform-engineering"
      DataClassification = "confidential"
    },
    var.tags
  )

  # ==============================================================================
  # VPC CONFIGURATION (Simplified - networking created in network module)
  # ==============================================================================
  availability_zones = var.vpc_config.availability_zones
  az_count           = length(local.availability_zones)

  # ==============================================================================
  # VPC ENDPOINTS CONFIGURATION
  # ==============================================================================
  # Gateway endpoints (free, use route tables)
  required_gateway_endpoints = toset(["s3", "dynamodb"])

  # Interface endpoints for AgentCore and AWS services
  # NOTE: bedrock-agentcore endpoints removed - they conflict with private hosted zones
  # and bedrock-agentcore-runtime service doesn't exist yet in all regions
  required_interface_endpoints = toset(concat(
    # Bedrock endpoints (for model invocation)
    [
      "bedrock-runtime",
      "bedrock",
    ],
    # Core AWS services
    [
      "ecr.api",
      "ecr.dkr",
      "logs",
      "monitoring",
      "secretsmanager",
      "ssm",
      "ssmmessages",
      "kms",
      "sts",
      "xray",
      "execute-api", # For API Gateway if used
    ]
  ))

  # ==============================================================================
  # FEATURE FLAGS
  # ==============================================================================
  memory_enabled   = var.scale_profile.enable_memory
  identity_enabled = var.scale_profile.enable_identity
  gateway_enabled  = var.scale_profile.enable_gateway
  tools_enabled    = var.scale_profile.enable_tools

  # ==============================================================================
  # AGENT NORMALIZATION
  # ==============================================================================
  agents_normalized = {
    for agent_key, agent in var.agents : agent_key => {
      name        = agent.name
      description = agent.description

      # Container configuration
      container_image_digest = agent.container_image_digest

      # Runtime configuration with defaults
      mode = agent.mode
      effective_memory_mb = coalesce(
        agent.memory_mb,
        var.scale_profile.runtime_memory_mb_default
      )
      effective_timeout_seconds = coalesce(
        agent.timeout_seconds,
        agent.mode == "realtime" ? min(var.scale_profile.runtime_timeout_seconds_default, 300) : var.scale_profile.runtime_timeout_seconds_default
      )
      effective_concurrency = coalesce(
        agent.concurrency,
        var.scale_profile.runtime_concurrency_limit
      )

      # IAM configuration
      capability_bundles = agent.capability_bundles
      custom_policy_arns = agent.custom_policy_arns

      # Feature integration
      memory_enabled  = agent.memory_enabled && local.memory_enabled
      gateway_enabled = agent.gateway_enabled && local.gateway_enabled
      tools_enabled   = agent.tools_enabled && local.tools_enabled

      # Tags
      effective_tags = merge(local.common_tags, agent.additional_tags, {
        AgentName = agent.name
        AgentKey  = agent_key
        AgentMode = agent.mode
      })
    }
  }

  # ==============================================================================
  # IAM NAMING
  # ==============================================================================
  execution_role_name_prefix = "${local.name_prefix}-agent-exec"
  permission_boundary_name   = "${local.name_prefix}-agent-boundary"

  # ==============================================================================
  # OBSERVABILITY NAMING
  # ==============================================================================
  log_group_prefix = "/aws/agentcore/${var.environment}"

  # ==============================================================================
  # MEMORY CONFIGURATION NORMALIZED
  # ==============================================================================
  memory_config_normalized = local.memory_enabled ? {
    session_memory = {
      enabled            = var.memory_config.session_memory.enabled
      ttl_hours          = var.scale_profile.memory_session_ttl_hours
      max_context_tokens = var.memory_config.session_memory.max_context_tokens
    }
    long_term_memory = {
      enabled            = var.memory_config.long_term_memory.enabled
      retention_days     = var.scale_profile.memory_long_term_retention_days
      encryption_key_arn = var.memory_config.long_term_memory.encryption_key_arn
    }
  } : null

  # ==============================================================================
  # GATEWAY CONFIGURATION NORMALIZED
  # ==============================================================================
  gateway_config_normalized = local.gateway_enabled ? {
    tool_policies = {
      for k, v in var.gateway_config.tool_policies : k => {
        tool_name      = v.tool_name
        allowed_agents = v.allowed_agents
        rate_limit = v.rate_limit != null ? v.rate_limit : {
          requests_per_minute = var.scale_profile.gateway_rate_limit_default
          burst_limit         = var.scale_profile.gateway_burst_limit_default
        }
        timeout_seconds = v.timeout_seconds
      }
    }
    connections = var.gateway_config.connections
  } : null

  # ==============================================================================
  # TOOLS CONFIGURATION NORMALIZED
  # ==============================================================================
  tools_config_normalized = local.tools_enabled ? {
    code_interpreter = {
      enabled               = var.tools_config.code_interpreter.enabled
      languages             = var.tools_config.code_interpreter.languages
      max_execution_seconds = var.scale_profile.code_interpreter_max_execution_seconds
      memory_mb             = var.scale_profile.code_interpreter_memory_mb
      allow_network         = var.tools_config.code_interpreter.allow_network
    }
    browser_tool = {
      enabled            = var.tools_config.browser_tool.enabled
      allowed_domains    = var.tools_config.browser_tool.allowed_domains
      blocked_domains    = var.tools_config.browser_tool.blocked_domains
      max_page_size_mb   = var.scale_profile.browser_max_page_size_mb
      screenshot_enabled = var.tools_config.browser_tool.screenshot_enabled
    }
  } : null

  # ==============================================================================
  # ENVIRONMENT INVARIANT VALIDATIONS
  # These use the tobool trick to fail at plan time with a message
  # ==============================================================================

  # Production MUST use NAT per AZ
  _validate_prod_nat = var.environment == "prod" ? (
    var.scale_profile.nat_mode == "per_az" ? true : tobool("ERROR: Production must use NAT per AZ for HA requirements")
  ) : true

  # Preprod MUST use NAT per AZ
  _validate_preprod_nat = var.environment == "preprod" ? (
    var.scale_profile.nat_mode == "per_az" ? true : tobool("ERROR: Preprod must use NAT per AZ to match production")
  ) : true

  # Production log retention MUST be at least 365 days
  _validate_prod_log_retention = var.environment == "prod" ? (
    var.scale_profile.log_retention_days >= 365 ? true : tobool("ERROR: Production log retention must be at least 365 days")
  ) : true

  # Production VPC endpoints MUST span at least 2 AZs
  _validate_prod_endpoint_ha = var.environment == "prod" ? (
    var.scale_profile.vpc_endpoint_az_count >= 2 ? true : tobool("ERROR: Production VPC endpoints must span at least 2 AZs")
  ) : true

  # Production memory retention MUST be at least 90 days
  _validate_prod_memory_retention = var.environment == "prod" && local.memory_enabled ? (
    var.scale_profile.memory_long_term_retention_days >= 90 ? true : tobool("ERROR: Production memory retention must be at least 90 days")
  ) : true
}

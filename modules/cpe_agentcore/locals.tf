locals {
  # ==============================================================================
  # NAMING CONVENTIONS
  # ==============================================================================
  name_prefix = "agentcore-${var.environment}"

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
  # VPC NORMALIZATION
  # ==============================================================================
  availability_zones = distinct([
    for subnet in var.vpc_config.private_subnet_ids : subnet.availability_zone
  ])

  az_count = length(local.availability_zones)

  # Normalize subnet list for iteration
  subnets_by_az = {
    for az in local.availability_zones : az => [
      for k, v in var.vpc_config.private_subnet_ids : v.subnet_id
      if v.availability_zone == az
    ][0]
  }

  # ==============================================================================
  # NAT GATEWAY LOGIC
  # ==============================================================================
  nat_gateway_count = var.scale_profile.nat_mode == "per_az" ? local.az_count : 1

  nat_gateway_azs = var.scale_profile.nat_mode == "per_az" ? local.availability_zones : [local.availability_zones[0]]

  # ==============================================================================
  # VPC ENDPOINTS CONFIGURATION
  # ==============================================================================
  # Core AWS services requiring VPC endpoints
  required_gateway_endpoints = toset(["s3", "dynamodb"])

  required_interface_endpoints = toset([
    "bedrock-agent-runtime",
    "bedrock-runtime",
    "bedrock",
    "ecr.api",
    "ecr.dkr",
    "logs",
    "monitoring",
    "secretsmanager",
    "ssm",
    "ssmmessages",
    "kms",
    "sts",
    "xray"
  ])

  # Limit interface endpoints to configured AZ count for cost optimization
  vpc_endpoint_subnet_ids = slice(
    [for az in local.availability_zones : local.subnets_by_az[az]],
    0,
    min(var.scale_profile.vpc_endpoint_az_count, local.az_count)
  )

  # ==============================================================================
  # AGENT NORMALIZATION
  # ==============================================================================
  agents_normalized = {
    for agent_key, agent in var.agents : agent_key => merge(agent, {
      # Apply defaults from scale_profile if not overridden
      effective_memory_mb = coalesce(
        agent.memory_mb_override,
        var.scale_profile.runtime_memory_mb
      )
      effective_timeout_seconds = coalesce(
        agent.timeout_seconds_override,
        var.scale_profile.runtime_timeout_seconds
      )
      # Merge tags
      effective_tags = merge(local.common_tags, agent.additional_tags, {
        AgentName = agent.name
        AgentKey  = agent_key
      })
    })
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
  # FEATURE FLAGS
  # ==============================================================================
  gateway_enabled = var.scale_profile.enable_gateway
  memory_enabled  = var.scale_profile.enable_memory

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
}


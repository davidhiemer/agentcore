# ==============================================================================
# ROOT MODULE ORCHESTRATION
# 
# This module orchestrates all internal submodules with explicit dependency ordering.
# Submodules are NOT independently consumable.
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# ECR REPOSITORIES
# First in dependency chain - provides container registry for runtime
# ------------------------------------------------------------------------------
module "ecr" {
  source = "./modules/ecr"

  environment = var.environment
  name_prefix = local.name_prefix
  agents      = local.agents_normalized

  # Cross-account pull access for runtime
  cross_account_access = var.cross_account_access

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# NETWORK INFRASTRUCTURE
# VPC endpoints and private DNS configuration
# Depends on: (none - VPC created externally)
# ------------------------------------------------------------------------------
module "network" {
  source = "./modules/network"

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # VPC configuration (passed through from external)
  vpc_id             = var.vpc_config.vpc_id
  private_subnet_ids = var.vpc_config.private_subnet_ids
  public_subnet_ids  = var.vpc_config.public_subnet_ids
  security_group_ids = var.vpc_config.security_group_ids
  route_table_ids    = var.vpc_config.route_table_ids

  # Normalized values from locals
  availability_zones      = local.availability_zones
  subnets_by_az           = local.subnets_by_az
  vpc_endpoint_subnet_ids = local.vpc_endpoint_subnet_ids

  # Scale profile
  nat_mode        = var.scale_profile.nat_mode
  nat_gateway_azs = local.nat_gateway_azs

  # VPC endpoints
  gateway_endpoints   = local.required_gateway_endpoints
  interface_endpoints = local.required_interface_endpoints

  # Cross-account private DNS
  cross_account_access = var.cross_account_access

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# IAM ROLES AND POLICIES
# Execution roles, capability bundles, permission boundaries
# Depends on: network (for VPC endpoint policies)
# ------------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"

  environment    = var.environment
  name_prefix    = local.name_prefix
  aws_account_id = var.aws_account_id
  aws_region     = var.aws_region

  # Agent configurations
  agents = local.agents_normalized

  # Permission boundary configuration
  permission_boundary_name = local.permission_boundary_name

  # Cross-account access
  cross_account_access = var.cross_account_access

  # Dependencies from network module
  vpc_endpoint_arns = module.network.vpc_endpoint_arns

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE RUNTIME
# Core runtime resources (VPC-attached)
# Depends on: network, iam, ecr
# ------------------------------------------------------------------------------
module "runtime" {
  source = "./modules/runtime"

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Agent configurations
  agents = local.agents_normalized

  # VPC attachment
  vpc_id            = var.vpc_config.vpc_id
  subnet_ids        = [for az, subnet_id in local.subnets_by_az : subnet_id]
  security_group_id = var.vpc_config.security_group_ids.agentcore_runtime

  # Scale profile
  concurrency_limit = var.scale_profile.runtime_concurrency_limit

  # Dependencies
  ecr_repository_urls = module.ecr.repository_urls
  execution_role_arns = module.iam.execution_role_arns

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE ENDPOINTS
# Runtime endpoints pinned to specific versions/digests
# Depends on: runtime
# ------------------------------------------------------------------------------
module "endpoints" {
  source = "./modules/endpoints"

  environment = var.environment
  name_prefix = local.name_prefix

  # Agent configurations with pinned digests
  agents = local.agents_normalized

  # Runtime dependencies
  runtime_arns = module.runtime.runtime_arns

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# OBSERVABILITY
# CloudWatch logs/metrics/alarms, Splunk forwarding
# Depends on: runtime, endpoints
# ------------------------------------------------------------------------------
module "observability" {
  source = "./modules/observability"

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Agent configurations
  agents = local.agents_normalized

  # Observability configuration
  log_group_prefix           = local.log_group_prefix
  log_retention_days         = var.scale_profile.log_retention_days
  metrics_resolution_seconds = var.scale_profile.metrics_resolution_seconds
  alarm_evaluation_periods   = var.scale_profile.alarm_evaluation_periods

  # Splunk integration
  splunk_hec_endpoint         = var.observability_config.splunk_hec_endpoint
  splunk_hec_token_secret_arn = var.observability_config.splunk_hec_token_secret_arn

  # Alerting
  alarm_sns_topic_arn = var.observability_config.alarm_sns_topic_arn

  # Feature flags
  enable_xray_tracing = var.observability_config.enable_xray_tracing
  dashboard_enabled   = var.observability_config.dashboard_enabled

  # Dependencies
  runtime_arns  = module.runtime.runtime_arns
  endpoint_arns = module.endpoints.endpoint_arns

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# GATEWAY (Future - Feature-flagged)
# Tool governance and connectivity
# ------------------------------------------------------------------------------
module "gateway" {
  source = "./modules/gateway"
  count  = local.gateway_enabled ? 1 : 0

  environment = var.environment
  name_prefix = local.name_prefix

  # Dependencies
  vpc_id              = var.vpc_config.vpc_id
  subnet_ids          = [for az, subnet_id in local.subnets_by_az : subnet_id]
  execution_role_arns = module.iam.execution_role_arns

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# MEMORY (Future - Feature-flagged)
# AgentCore Memory
# ------------------------------------------------------------------------------
module "memory" {
  source = "./modules/memory"
  count  = local.memory_enabled ? 1 : 0

  environment = var.environment
  name_prefix = local.name_prefix

  # Dependencies
  vpc_id              = var.vpc_config.vpc_id
  subnet_ids          = [for az, subnet_id in local.subnets_by_az : subnet_id]
  execution_role_arns = module.iam.execution_role_arns

  tags = local.common_tags
}


# ==============================================================================
# ROOT MODULE ORCHESTRATION
# 
# Amazon Bedrock AgentCore Platform
# This module orchestrates all internal submodules with explicit dependency ordering.
# Submodules are NOT independently consumable.
#
# Uses aws_bedrockagentcore_* resources (AWS provider >= 6.17.0)
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime
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

  # Feature flags for capability bundles
  memory_enabled  = local.memory_enabled
  gateway_enabled = local.gateway_enabled
  tools_enabled   = local.tools_enabled

  # Dependencies from network module
  vpc_endpoint_arns = module.network.vpc_endpoint_arns

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE IDENTITY
# Enterprise identity provider integration
# Depends on: iam
# ------------------------------------------------------------------------------
module "identity" {
  source = "./modules/identity"
  count  = local.identity_enabled ? 1 : 0

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Identity configuration
  identity_config = var.identity_config

  # Agent configurations for role mappings
  agents = local.agents_normalized

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE RUNTIME & ENDPOINTS
# Core runtime resources for containerized agents
# Creates aws_bedrockagentcore_agent_runtime and aws_bedrockagentcore_agent_runtime_endpoint
# Depends on: network, iam, ecr, identity
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
  subnet_ids        = local.subnet_ids_list
  security_group_id = var.vpc_config.security_group_ids.agentcore_runtime

  # Dependencies
  ecr_repository_urls = module.ecr.repository_urls
  execution_role_arns = module.iam.execution_role_arns

  # Identity integration
  identity_provider_arn = local.identity_enabled ? module.identity[0].provider_arn : null

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE ENDPOINT POLICIES
# Cross-account access and endpoint aliases for versioning
# Depends on: runtime
# ------------------------------------------------------------------------------
module "endpoints" {
  source = "./modules/endpoints"

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Agent configurations with pinned digests
  agents = local.agents_normalized

  # Runtime dependencies - endpoints created in runtime module
  runtime_arns  = module.runtime.runtime_arns
  runtime_ids   = module.runtime.runtime_ids
  endpoint_arns = module.runtime.endpoint_arns
  endpoint_urls = module.runtime.endpoint_urls

  # Cross-account access for endpoint invocation
  cross_account_access = var.cross_account_access

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE MEMORY
# Session and long-term memory for agents
# Depends on: iam, runtime
# ------------------------------------------------------------------------------
module "memory" {
  source = "./modules/memory"
  count  = local.memory_enabled ? 1 : 0

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Memory configuration
  memory_config = local.memory_config_normalized

  # Agent configurations
  agents = local.agents_normalized

  # VPC attachment
  vpc_id     = var.vpc_config.vpc_id
  subnet_ids = local.subnet_ids_list

  # Dependencies
  execution_role_arns = module.iam.execution_role_arns
  runtime_ids         = module.runtime.runtime_ids

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE GATEWAY
# Tool governance and connectivity
# Depends on: iam, runtime
# ------------------------------------------------------------------------------
module "gateway" {
  source = "./modules/gateway"
  count  = local.gateway_enabled ? 1 : 0

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Gateway configuration
  gateway_config = local.gateway_config_normalized

  # Agent configurations
  agents = local.agents_normalized

  # VPC attachment
  vpc_id     = var.vpc_config.vpc_id
  subnet_ids = local.subnet_ids_list

  # Dependencies
  execution_role_arns = module.iam.execution_role_arns
  runtime_ids         = module.runtime.runtime_ids

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE TOOLS
# Code Interpreter and Browser Tool
# Depends on: iam, runtime, gateway
# ------------------------------------------------------------------------------
module "tools" {
  source = "./modules/tools"
  count  = local.tools_enabled ? 1 : 0

  environment = var.environment
  name_prefix = local.name_prefix
  aws_region  = var.aws_region

  # Tools configuration
  tools_config = local.tools_config_normalized

  # Agent configurations
  agents = local.agents_normalized

  # VPC attachment
  vpc_id     = var.vpc_config.vpc_id
  subnet_ids = local.subnet_ids_list

  # Dependencies
  execution_role_arns = module.iam.execution_role_arns
  runtime_ids         = module.runtime.runtime_ids
  gateway_arn         = local.gateway_enabled ? module.gateway[0].gateway_arn : null

  tags = local.common_tags
}

# ------------------------------------------------------------------------------
# OBSERVABILITY
# CloudWatch logs/metrics/alarms, Splunk forwarding
# Depends on: runtime, memory, gateway, tools
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
  xray_sampling_rate         = var.scale_profile.xray_sampling_rate

  # Splunk integration
  splunk_hec_endpoint         = var.observability_config.splunk_hec_endpoint
  splunk_hec_token_secret_arn = var.observability_config.splunk_hec_token_secret_arn

  # Alerting
  alarm_sns_topic_arn = var.observability_config.alarm_sns_topic_arn

  # Feature flags
  enable_xray_tracing = var.observability_config.enable_xray_tracing
  dashboard_enabled   = var.observability_config.dashboard_enabled

  # Component feature flags
  memory_enabled  = local.memory_enabled
  gateway_enabled = local.gateway_enabled
  tools_enabled   = local.tools_enabled

  # Dependencies - endpoints now come from runtime module
  runtime_arns  = module.runtime.runtime_arns
  endpoint_arns = module.runtime.endpoint_arns
  memory_arns   = local.memory_enabled ? module.memory[0].memory_store_arns : {}
  gateway_arn   = local.gateway_enabled ? module.gateway[0].gateway_arn : null
  tools_arns    = local.tools_enabled ? module.tools[0].tools_arns : {}

  tags = local.common_tags
}

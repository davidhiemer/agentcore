# ==============================================================================
# DEV ENVIRONMENT EXAMPLE
# ==============================================================================

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "bank-terraform-state-dev"
    key            = "agentcore/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

module "agentcore" {
  source = "../../"

  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  vpc_config           = var.vpc_config
  scale_profile        = var.scale_profile
  agents               = var.agents
  memory_config        = var.memory_config
  identity_config      = var.identity_config
  gateway_config       = var.gateway_config
  tools_config         = var.tools_config
  cross_account_access = var.cross_account_access
  observability_config = var.observability_config
  tags                 = var.tags
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "ecr_repository_urls" {
  value = module.agentcore.ecr_repository_urls
}

output "execution_role_arns" {
  value = module.agentcore.execution_role_arns
}

output "endpoint_ids" {
  value = module.agentcore.endpoint_ids
}

output "log_group_names" {
  value = module.agentcore.log_group_names
}

# Network outputs (created by module)
output "private_subnet_ids" {
  description = "Private subnet IDs created by the module"
  value       = module.agentcore.private_subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs created by the module"
  value       = module.agentcore.security_group_ids
}

output "nat_gateway_public_ips" {
  description = "NAT Gateway public IPs"
  value       = module.agentcore.nat_gateway_public_ips
}

# Memory outputs (if enabled)
output "memory_endpoint_url" {
  description = "Memory service endpoint URL"
  value       = module.agentcore.memory_endpoint_url
}

# Gateway outputs (if enabled)
output "gateway_endpoint_url" {
  description = "Gateway endpoint URL"
  value       = module.agentcore.gateway_endpoint_url
}

output "gateway_tool_registry" {
  description = "Registered tools in gateway"
  value       = module.agentcore.gateway_tool_registry
}

# Tools outputs (if enabled)
output "code_interpreter_endpoint_url" {
  description = "Code Interpreter endpoint URL"
  value       = module.agentcore.code_interpreter_endpoint_url
}

output "browser_tool_endpoint_url" {
  description = "Browser Tool endpoint URL"
  value       = module.agentcore.browser_tool_endpoint_url
}

output "summary" {
  value = module.agentcore.summary
}



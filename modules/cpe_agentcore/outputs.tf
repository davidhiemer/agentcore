# ==============================================================================
# ROOT MODULE OUTPUTS
# ==============================================================================

# ------------------------------------------------------------------------------
# ECR
# ------------------------------------------------------------------------------
output "ecr_repository_urls" {
  description = "Map of agent key to ECR repository URL"
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "Map of agent key to ECR repository ARN"
  value       = module.ecr.repository_arns
}

# ------------------------------------------------------------------------------
# NETWORK
# ------------------------------------------------------------------------------
output "vpc_endpoint_ids" {
  description = "Map of service to VPC endpoint ID"
  value       = module.network.vpc_endpoint_ids
}

output "private_hosted_zone_id" {
  description = "Route 53 private hosted zone ID for AgentCore"
  value       = module.network.private_hosted_zone_id
}

output "nat_gateway_ids" {
  description = "List of NAT Gateway IDs"
  value       = module.network.nat_gateway_ids
}

output "nat_gateway_public_ips" {
  description = "Map of AZ to NAT Gateway public IP"
  value       = module.network.nat_gateway_public_ips
}

# ------------------------------------------------------------------------------
# IAM
# ------------------------------------------------------------------------------
output "execution_role_arns" {
  description = "Map of agent key to execution role ARN"
  value       = module.iam.execution_role_arns
}

output "execution_role_names" {
  description = "Map of agent key to execution role name"
  value       = module.iam.execution_role_names
}

output "permission_boundary_arn" {
  description = "ARN of the permission boundary policy"
  value       = module.iam.permission_boundary_arn
}

output "capability_bundle_arns" {
  description = "Map of capability bundle name to policy ARN"
  value       = module.iam.capability_bundle_arns
}

# ------------------------------------------------------------------------------
# RUNTIME
# ------------------------------------------------------------------------------
output "runtime_arns" {
  description = "Map of agent key to runtime ARN"
  value       = module.runtime.runtime_arns
}

output "runtime_ids" {
  description = "Map of agent key to runtime ID"
  value       = module.runtime.runtime_ids
}

# ------------------------------------------------------------------------------
# ENDPOINTS
# ------------------------------------------------------------------------------
output "endpoint_arns" {
  description = "Map of agent key to endpoint ARN"
  value       = module.endpoints.endpoint_arns
}

output "endpoint_ids" {
  description = "Map of agent key to endpoint ID"
  value       = module.endpoints.endpoint_ids
}

# ------------------------------------------------------------------------------
# OBSERVABILITY
# ------------------------------------------------------------------------------
output "log_group_arns" {
  description = "Map of agent key to CloudWatch log group ARN"
  value       = module.observability.log_group_arns
}

output "log_group_names" {
  description = "Map of agent key to CloudWatch log group name"
  value       = module.observability.log_group_names
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.observability.dashboard_url
}

output "alarm_arns" {
  description = "Map of alarm name to alarm ARN"
  value       = module.observability.alarm_arns
}

output "firehose_arn" {
  description = "ARN of the Kinesis Firehose delivery stream for Splunk"
  value       = module.observability.firehose_arn
}

# ------------------------------------------------------------------------------
# GATEWAY (Future)
# ------------------------------------------------------------------------------
output "gateway_endpoint" {
  description = "Gateway endpoint URL (if enabled)"
  value       = local.gateway_enabled ? module.gateway[0].endpoint_url : null
}

# ------------------------------------------------------------------------------
# MEMORY (Future)
# ------------------------------------------------------------------------------
output "memory_endpoint" {
  description = "Memory endpoint URL (if enabled)"
  value       = local.memory_enabled ? module.memory[0].endpoint_url : null
}

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------
output "summary" {
  description = "Summary of deployed resources"
  value = {
    environment = var.environment
    region      = var.aws_region
    account_id  = var.aws_account_id
    agents      = keys(var.agents)
    nat_mode    = var.scale_profile.nat_mode
    features = {
      gateway = local.gateway_enabled
      memory  = local.memory_enabled
    }
  }
}


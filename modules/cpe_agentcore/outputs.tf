# ==============================================================================
# ROOT MODULE OUTPUTS
# Amazon Bedrock AgentCore Platform
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
# IDENTITY
# ------------------------------------------------------------------------------
output "identity_provider_arn" {
  description = "ARN of the identity provider (if enabled)"
  value       = local.identity_enabled ? module.identity[0].provider_arn : null
}

output "identity_endpoint_url" {
  description = "Identity service endpoint URL (if enabled)"
  value       = local.identity_enabled ? module.identity[0].endpoint_url : null
}

output "identity_user_pool_id" {
  description = "Cognito User Pool ID (if using Cognito)"
  value       = local.identity_enabled ? module.identity[0].user_pool_id : null
}

# ------------------------------------------------------------------------------
# RUNTIME
# ------------------------------------------------------------------------------
output "runtime_arns" {
  description = "Map of agent key to AgentCore Runtime ARN"
  value       = module.runtime.runtime_arns
}

output "runtime_ids" {
  description = "Map of agent key to AgentCore Runtime ID"
  value       = module.runtime.runtime_ids
}

output "runtime_status" {
  description = "Map of agent key to runtime status"
  value       = module.runtime.runtime_status
}

# ------------------------------------------------------------------------------
# ENDPOINTS
# ------------------------------------------------------------------------------
output "endpoint_arns" {
  description = "Map of agent key to endpoint ARN"
  value       = module.runtime.endpoint_arns
}

output "endpoint_ids" {
  description = "Map of agent key to endpoint ID"
  value       = module.endpoints.endpoint_ids
}

output "endpoint_urls" {
  description = "Map of agent key to endpoint invocation URL"
  value       = module.runtime.endpoint_urls
}

# ------------------------------------------------------------------------------
# MEMORY
# ------------------------------------------------------------------------------
output "memory_store_arns" {
  description = "Map of agent key to memory store ARN (if enabled)"
  value       = local.memory_enabled ? module.memory[0].memory_store_arns : {}
}

output "memory_endpoint_url" {
  description = "Memory service endpoint URL (if enabled)"
  value       = local.memory_enabled ? module.memory[0].endpoint_url : null
}

output "memory_session_table_name" {
  description = "DynamoDB table name for session memory (if enabled)"
  value       = local.memory_enabled ? module.memory[0].session_table_name : null
}

output "memory_knowledge_store_id" {
  description = "Knowledge store ID for long-term memory (if enabled)"
  value       = local.memory_enabled ? module.memory[0].knowledge_store_id : null
}

# ------------------------------------------------------------------------------
# GATEWAY
# ------------------------------------------------------------------------------
output "gateway_arn" {
  description = "Gateway ARN (if enabled)"
  value       = local.gateway_enabled ? module.gateway[0].gateway_arn : null
}

output "gateway_endpoint_url" {
  description = "Gateway endpoint URL (if enabled)"
  value       = local.gateway_enabled ? module.gateway[0].endpoint_url : null
}

output "gateway_tool_registry" {
  description = "Map of registered tools in gateway (if enabled)"
  value       = local.gateway_enabled ? module.gateway[0].tool_registry : {}
}

output "gateway_connection_ids" {
  description = "Map of connection name to connection ID (if enabled)"
  value       = local.gateway_enabled ? module.gateway[0].connection_ids : {}
}

# ------------------------------------------------------------------------------
# TOOLS
# ------------------------------------------------------------------------------
output "code_interpreter_arn" {
  description = "Code Interpreter ARN (if enabled)"
  value       = local.tools_enabled ? module.tools[0].code_interpreter_arn : null
}

output "code_interpreter_endpoint_url" {
  description = "Code Interpreter endpoint URL (if enabled)"
  value       = local.tools_enabled ? module.tools[0].code_interpreter_endpoint_url : null
}

output "browser_tool_arn" {
  description = "Browser Tool ARN (if enabled)"
  value       = local.tools_enabled ? module.tools[0].browser_tool_arn : null
}

output "browser_tool_endpoint_url" {
  description = "Browser Tool endpoint URL (if enabled)"
  value       = local.tools_enabled ? module.tools[0].browser_tool_endpoint_url : null
}

output "tools_arns" {
  description = "Map of tool name to ARN (if enabled)"
  value       = local.tools_enabled ? module.tools[0].tools_arns : {}
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

output "xray_group_arn" {
  description = "ARN of the X-Ray sampling group"
  value       = module.observability.xray_group_arn
}

# ------------------------------------------------------------------------------
# SUMMARY
# ------------------------------------------------------------------------------
output "summary" {
  description = "Summary of deployed AgentCore platform resources"
  value = {
    environment = var.environment
    region      = var.aws_region
    account_id  = var.aws_account_id

    agents = {
      for k, v in local.agents_normalized : k => {
        name   = v.name
        mode   = v.mode
        memory = v.memory_enabled
        tools  = v.tools_enabled
      }
    }

    infrastructure = {
      nat_mode                = var.scale_profile.nat_mode
      vpc_endpoint_az_count   = var.scale_profile.vpc_endpoint_az_count
      runtime_concurrency     = var.scale_profile.runtime_concurrency_limit
    }

    features = {
      memory   = local.memory_enabled
      identity = local.identity_enabled
      gateway  = local.gateway_enabled
      tools    = local.tools_enabled
    }

    endpoints = module.runtime.endpoint_urls
  }
}

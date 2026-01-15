output "provider_arn" {
  description = "ARN of the identity provider"
  value       = local.provider_arn
}

output "endpoint_url" {
  description = "Identity provider endpoint URL"
  value       = local.endpoint_url
}

output "user_pool_id" {
  description = "Cognito User Pool ID (if using Cognito)"
  value       = local.user_pool_id
}

output "user_pool_arn" {
  description = "Cognito User Pool ARN (if using Cognito)"
  value       = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? aws_cognito_user_pool.agentcore[0].arn : null
}

output "user_pool_client_id" {
  description = "Cognito User Pool Client ID (if using Cognito)"
  value       = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? aws_cognito_user_pool_client.agentcore[0].id : null
}

output "user_pool_domain" {
  description = "Cognito User Pool Domain (if using Cognito)"
  value       = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? aws_cognito_user_pool_domain.agentcore[0].domain : null
}

output "group_names" {
  description = "Map of group name to agent keys"
  value = var.identity_config.enabled ? {
    for k, v in aws_cognito_user_group.agent_access : k => v.name
  } : {}
}

output "config_parameter_arn" {
  description = "SSM parameter ARN containing identity configuration"
  value       = var.identity_config.enabled ? aws_ssm_parameter.identity_config[0].arn : null
}


# Endpoints are created in the runtime module
# This module just manages policies and aliases

output "endpoint_arns" {
  description = "Map of agent key to endpoint ARN (passthrough from runtime)"
  value       = var.endpoint_arns
}

output "endpoint_ids" {
  description = "Map of agent key to endpoint ID"
  value = {
    for k, v in var.agents : k => "${var.name_prefix}-${k}-endpoint"
  }
}

output "endpoint_urls" {
  description = "Map of agent key to endpoint invocation URL (passthrough from runtime)"
  value       = var.endpoint_urls
}

output "endpoint_config_parameters" {
  description = "Map of agent key to SSM parameter ARN containing endpoint config"
  value       = { for k, v in aws_ssm_parameter.endpoint_config : k => v.arn }
}

output "endpoint_aliases" {
  description = "Map of agent key to live alias SSM parameter ARN"
  value       = { for k, v in aws_ssm_parameter.endpoint_alias_live : k => v.arn }
}

output "cross_account_policy_arn" {
  description = "SSM parameter ARN containing cross-account access policy"
  value       = var.cross_account_access.enabled ? aws_ssm_parameter.endpoint_access_policy[0].arn : null
}

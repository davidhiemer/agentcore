output "endpoint_arns" {
  description = "Map of agent key to endpoint ARN (SSM parameter ARN for now)"
  value       = { for k, v in aws_ssm_parameter.endpoint_config : k => v.arn }
}

output "endpoint_ids" {
  description = "Map of agent key to endpoint ID (SSM parameter name for now)"
  value       = { for k, v in aws_ssm_parameter.endpoint_config : k => v.name }
}

output "deployed_versions" {
  description = "Map of agent key to currently deployed digest"
  value       = { for k, v in aws_ssm_parameter.version_history : k => v.value }
}


output "endpoint_arns" {
  description = "Map of agent key to endpoint ARN"
  value       = local.endpoint_arns
}

output "endpoint_ids" {
  description = "Map of agent key to endpoint ID"
  value       = local.endpoint_ids
}

output "endpoint_urls" {
  description = "Map of agent key to endpoint invocation URL"
  value       = local.endpoint_urls
}

output "endpoint_config_parameters" {
  description = "Map of agent key to SSM parameter ARN containing endpoint config"
  value       = { for k, v in aws_ssm_parameter.endpoint_config : k => v.arn }
}

output "endpoint_aliases" {
  description = "Map of agent key to live alias SSM parameter ARN"
  value       = { for k, v in aws_ssm_parameter.endpoint_alias_live : k => v.arn }
}

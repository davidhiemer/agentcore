output "runtime_arns" {
  description = "Map of agent key to AgentCore Runtime ARN"
  value       = local.runtime_arns
}

output "runtime_ids" {
  description = "Map of agent key to AgentCore Runtime ID"
  value       = local.runtime_ids
}

output "runtime_status" {
  description = "Map of agent key to runtime status"
  value       = local.runtime_status
}

output "runtime_config_parameters" {
  description = "Map of agent key to SSM parameter ARN containing runtime config"
  value       = { for k, v in aws_ssm_parameter.runtime_config : k => v.arn }
}

output "log_group_arns" {
  description = "Map of agent key to CloudWatch log group ARN"
  value       = { for k, v in aws_cloudwatch_log_group.agent_runtime : k => v.arn }
}

output "log_group_names" {
  description = "Map of agent key to CloudWatch log group name"
  value       = { for k, v in aws_cloudwatch_log_group.agent_runtime : k => v.name }
}

output "runtime_arns" {
  description = "Map of agent key to runtime ARN"
  value       = { for k, v in awscc_bedrock_agent.agent : k => v.agent_arn }
}

output "runtime_ids" {
  description = "Map of agent key to runtime ID"
  value       = { for k, v in awscc_bedrock_agent.agent : k => v.agent_id }
}

output "alias_arns" {
  description = "Map of agent key to alias ARN"
  value       = { for k, v in awscc_bedrock_agent_alias.agent : k => v.agent_alias_arn }
}

output "alias_ids" {
  description = "Map of agent key to alias ID"
  value       = { for k, v in awscc_bedrock_agent_alias.agent : k => v.agent_alias_id }
}


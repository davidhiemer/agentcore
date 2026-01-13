output "execution_role_arns" {
  description = "Map of agent key to execution role ARN"
  value       = { for k, v in aws_iam_role.agent_execution : k => v.arn }
}

output "execution_role_names" {
  description = "Map of agent key to execution role name"
  value       = { for k, v in aws_iam_role.agent_execution : k => v.name }
}

output "permission_boundary_arn" {
  description = "ARN of the permission boundary policy"
  value       = aws_iam_policy.permission_boundary.arn
}

output "capability_bundle_arns" {
  description = "Map of capability bundle name to policy ARN"
  value       = { for k, v in aws_iam_policy.capability_bundle : k => v.arn }
}


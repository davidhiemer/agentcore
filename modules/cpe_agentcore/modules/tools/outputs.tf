output "code_interpreter_arn" {
  description = "Code Interpreter ARN"
  value       = local.code_interpreter_arn
}

output "code_interpreter_endpoint_url" {
  description = "Code Interpreter endpoint URL"
  value       = local.code_interpreter_endpoint_url
}

output "code_interpreter_bucket_name" {
  description = "S3 bucket name for Code Interpreter artifacts"
  value       = var.tools_config.code_interpreter.enabled ? aws_s3_bucket.code_interpreter[0].id : null
}

output "code_interpreter_log_group" {
  description = "CloudWatch log group name for Code Interpreter"
  value       = var.tools_config.code_interpreter.enabled ? aws_cloudwatch_log_group.code_interpreter[0].name : null
}

output "browser_tool_arn" {
  description = "Browser Tool ARN"
  value       = local.browser_tool_arn
}

output "browser_tool_endpoint_url" {
  description = "Browser Tool endpoint URL"
  value       = local.browser_tool_endpoint_url
}

output "browser_tool_bucket_name" {
  description = "S3 bucket name for Browser Tool artifacts"
  value       = var.tools_config.browser_tool.enabled ? aws_s3_bucket.browser_tool[0].id : null
}

output "browser_tool_log_group" {
  description = "CloudWatch log group name for Browser Tool"
  value       = var.tools_config.browser_tool.enabled ? aws_cloudwatch_log_group.browser_tool[0].name : null
}

output "tools_arns" {
  description = "Map of tool name to ARN"
  value       = local.tools_arns
}

output "config_parameter_arn" {
  description = "SSM parameter ARN containing tools configuration"
  value       = aws_ssm_parameter.tools_config.arn
}


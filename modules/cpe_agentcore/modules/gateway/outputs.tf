output "gateway_arn" {
  description = "ARN of the API Gateway"
  value       = local.gateway_arn
}

output "endpoint_url" {
  description = "Gateway endpoint URL"
  value       = local.endpoint_url
}

output "tool_registry" {
  description = "Map of registered tools"
  value       = local.tool_registry
}

output "connection_ids" {
  description = "Map of connection name to secret ID"
  value       = local.connection_ids
}

output "tool_registry_table_name" {
  description = "DynamoDB table name for tool registry"
  value       = aws_dynamodb_table.tool_registry.name
}

output "tool_registry_table_arn" {
  description = "DynamoDB table ARN for tool registry"
  value       = aws_dynamodb_table.tool_registry.arn
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.gateway.id
}

output "api_gateway_stage" {
  description = "API Gateway stage name"
  value       = aws_api_gateway_stage.gateway.stage_name
}

output "config_parameter_arn" {
  description = "SSM parameter ARN containing gateway configuration"
  value       = aws_ssm_parameter.gateway_config.arn
}

output "access_log_group_arn" {
  description = "CloudWatch log group ARN for API Gateway access logs"
  value       = aws_cloudwatch_log_group.gateway_access.arn
}

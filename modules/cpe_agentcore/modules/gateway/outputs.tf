output "endpoint_url" {
  description = "Gateway endpoint URL (placeholder)"
  value       = "https://gateway.${var.environment}.internal"
}

output "config_parameter_arn" {
  description = "ARN of gateway configuration parameter"
  value       = aws_ssm_parameter.gateway_config.arn
}


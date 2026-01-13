output "endpoint_url" {
  description = "Memory endpoint URL (placeholder)"
  value       = "https://memory.${var.environment}.internal"
}

output "config_parameter_arn" {
  description = "ARN of memory configuration parameter"
  value       = aws_ssm_parameter.memory_config.arn
}


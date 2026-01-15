output "memory_store_arns" {
  description = "Map of memory store type to ARN"
  value       = local.memory_store_arns
}

output "endpoint_url" {
  description = "Memory service endpoint URL"
  value       = local.endpoint_url
}

output "session_table_name" {
  description = "DynamoDB table name for session memory"
  value       = var.memory_config.session_memory.enabled ? aws_dynamodb_table.session_memory[0].name : null
}

output "session_table_arn" {
  description = "DynamoDB table ARN for session memory"
  value       = var.memory_config.session_memory.enabled ? aws_dynamodb_table.session_memory[0].arn : null
}

output "knowledge_store_id" {
  description = "Knowledge store ID (DynamoDB table name)"
  value       = var.memory_config.long_term_memory.enabled ? aws_dynamodb_table.knowledge_store[0].name : null
}

output "knowledge_store_arn" {
  description = "Knowledge store ARN"
  value       = var.memory_config.long_term_memory.enabled ? aws_dynamodb_table.knowledge_store[0].arn : null
}

output "objects_bucket_name" {
  description = "S3 bucket name for large memory objects"
  value       = aws_s3_bucket.memory_objects.id
}

output "objects_bucket_arn" {
  description = "S3 bucket ARN for large memory objects"
  value       = aws_s3_bucket.memory_objects.arn
}

output "kms_key_arn" {
  description = "KMS key ARN for memory encryption"
  value       = aws_kms_key.memory.arn
}

output "config_parameter_arn" {
  description = "SSM parameter ARN containing memory configuration"
  value       = aws_ssm_parameter.memory_config.arn
}

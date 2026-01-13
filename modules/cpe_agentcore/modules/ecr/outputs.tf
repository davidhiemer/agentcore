output "repository_urls" {
  description = "Map of agent key to ECR repository URL"
  value       = { for k, v in aws_ecr_repository.agent : k => v.repository_url }
}

output "repository_arns" {
  description = "Map of agent key to ECR repository ARN"
  value       = { for k, v in aws_ecr_repository.agent : k => v.arn }
}

output "kms_key_arn" {
  description = "ARN of the KMS key used for ECR encryption"
  value       = aws_kms_key.ecr.arn
}


output "log_group_arns" {
  description = "Map of agent key to log group ARN"
  value       = { for k, v in aws_cloudwatch_log_group.agent : k => v.arn }
}

output "log_group_names" {
  description = "Map of agent key to log group name"
  value       = { for k, v in aws_cloudwatch_log_group.agent : k => v.name }
}

output "dashboard_url" {
  description = "CloudWatch dashboard URL"
  value = var.dashboard_enabled ? (
    "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.agentcore[0].dashboard_name}"
  ) : null
}

output "alarm_arns" {
  description = "Map of alarm name to alarm ARN"
  value       = { for k, v in aws_cloudwatch_metric_alarm.high_error_rate : k => v.arn }
}

output "firehose_arn" {
  description = "ARN of Kinesis Firehose delivery stream"
  value       = aws_kinesis_firehose_delivery_stream.splunk.arn
}

output "kms_key_arn" {
  description = "ARN of KMS key for log encryption"
  value       = aws_kms_key.logs.arn
}


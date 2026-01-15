output "log_group_arns" {
  description = "Map of agent key to CloudWatch log group ARN"
  value       = { for k, v in aws_cloudwatch_log_group.agent : k => v.arn }
}

output "log_group_names" {
  description = "Map of agent key to CloudWatch log group name"
  value       = { for k, v in aws_cloudwatch_log_group.agent : k => v.name }
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value = var.dashboard_enabled ? (
    "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.agentcore[0].dashboard_name}"
  ) : null
}

output "alarm_arns" {
  description = "Map of alarm name to alarm ARN"
  value = merge(
    { for k, v in aws_cloudwatch_metric_alarm.high_error_rate : "${k}-high-error-rate" => v.arn },
    { for k, v in aws_cloudwatch_metric_alarm.high_latency : "${k}-high-latency" => v.arn },
    var.memory_enabled ? { "memory-throttling" = aws_cloudwatch_metric_alarm.memory_throttling[0].arn } : {},
    var.gateway_enabled ? { "gateway-5xx-errors" = aws_cloudwatch_metric_alarm.gateway_5xx_errors[0].arn } : {}
  )
}

output "firehose_arn" {
  description = "ARN of the Kinesis Firehose delivery stream for Splunk"
  value       = aws_kinesis_firehose_delivery_stream.splunk.arn
}

output "firehose_name" {
  description = "Name of the Kinesis Firehose delivery stream for Splunk"
  value       = aws_kinesis_firehose_delivery_stream.splunk.name
}

output "xray_group_arn" {
  description = "ARN of the X-Ray sampling group"
  value       = var.enable_xray_tracing ? aws_xray_group.agentcore[0].arn : null
}

output "xray_sampling_rule_arn" {
  description = "ARN of the X-Ray sampling rule"
  value       = var.enable_xray_tracing ? aws_xray_sampling_rule.agentcore[0].arn : null
}

output "kms_key_arn" {
  description = "KMS key ARN for log encryption"
  value       = aws_kms_key.logs.arn
}

output "firehose_backup_bucket_arn" {
  description = "S3 bucket ARN for Firehose backup"
  value       = aws_s3_bucket.firehose_backup.arn
}

output "component_log_groups" {
  description = "Map of component to log group ARN"
  value = merge(
    var.memory_enabled ? { memory = aws_cloudwatch_log_group.memory[0].arn } : {},
    var.gateway_enabled ? { gateway = aws_cloudwatch_log_group.gateway[0].arn } : {},
    var.tools_enabled ? { tools = aws_cloudwatch_log_group.tools[0].arn } : {}
  )
}

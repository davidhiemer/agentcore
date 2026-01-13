variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "agents" {
  description = "Normalized agent configurations"
  type = map(object({
    name           = string
    effective_tags = map(string)
  }))
}

variable "log_group_prefix" {
  description = "Prefix for CloudWatch log groups"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention in days"
  type        = number
}

variable "metrics_resolution_seconds" {
  description = "CloudWatch metrics resolution"
  type        = number
}

variable "alarm_evaluation_periods" {
  description = "Number of evaluation periods for alarms"
  type        = number
}

variable "splunk_hec_endpoint" {
  description = "Splunk HEC endpoint URL"
  type        = string
}

variable "splunk_hec_token_secret_arn" {
  description = "ARN of Secrets Manager secret containing Splunk HEC token"
  type        = string
}

variable "alarm_sns_topic_arn" {
  description = "SNS topic ARN for alarm notifications"
  type        = string
}

variable "enable_xray_tracing" {
  description = "Whether to enable X-Ray tracing"
  type        = bool
}

variable "dashboard_enabled" {
  description = "Whether to create CloudWatch dashboard"
  type        = bool
}

variable "runtime_arns" {
  description = "Map of agent key to runtime ARN"
  type        = map(string)
}

variable "endpoint_arns" {
  description = "Map of agent key to endpoint ARN"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


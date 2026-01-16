# ==============================================================================
# OBSERVABILITY SUBMODULE
# CloudWatch logs, metrics, alarms, X-Ray tracing, and Splunk forwarding
# For Amazon Bedrock AgentCore Platform
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# LOG ENCRYPTION
# ------------------------------------------------------------------------------

resource "aws_kms_key" "logs" {
  description             = "${var.name_prefix}-logs-encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow CloudWatch Logs"
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          ArnLike = {
            "kms:EncryptionContext:aws:logs:arn" = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:${var.log_group_prefix}/*"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "random_id" "logs_key_suffix" {
  byte_length = 4
}

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-logs-${random_id.logs_key_suffix.hex}"
  target_key_id = aws_kms_key.logs.key_id
}

# ------------------------------------------------------------------------------
# LOG GROUPS - RUNTIME
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "agent" {
  for_each = var.agents

  name              = "${var.log_group_prefix}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    AgentName = each.value.name
    AgentKey  = each.key
    Component = "runtime"
  })
}

# ------------------------------------------------------------------------------
# LOG GROUPS - PLATFORM COMPONENTS
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "memory" {
  count = var.memory_enabled ? 1 : 0

  name              = "${var.log_group_prefix}/memory"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Component = "memory"
  })
}

resource "aws_cloudwatch_log_group" "gateway" {
  count = var.gateway_enabled ? 1 : 0

  name              = "${var.log_group_prefix}/gateway"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Component = "gateway"
  })
}

resource "aws_cloudwatch_log_group" "tools" {
  count = var.tools_enabled ? 1 : 0

  name              = "${var.log_group_prefix}/tools"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    Component = "tools"
  })
}

# ------------------------------------------------------------------------------
# X-RAY SAMPLING RULE
# ------------------------------------------------------------------------------

resource "aws_xray_sampling_rule" "agentcore" {
  count = var.enable_xray_tracing ? 1 : 0

  rule_name      = "${var.name_prefix}-sampling"
  priority       = 1000
  version        = 1
  reservoir_size = 10
  fixed_rate     = var.xray_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "agentcore-${var.environment}"
  resource_arn   = "*"

  attributes = {}
}

resource "aws_xray_group" "agentcore" {
  count = var.enable_xray_tracing ? 1 : 0

  group_name        = "${var.name_prefix}-traces"
  filter_expression = "service(id(name: \"agentcore-${var.environment}\"))"

  insights_configuration {
    insights_enabled      = true
    notifications_enabled = true
  }

  tags = var.tags
}

# ------------------------------------------------------------------------------
# METRIC FILTERS - RUNTIME
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "errors" {
  for_each = var.agents

  name           = "${var.name_prefix}-${each.key}-errors"
  log_group_name = aws_cloudwatch_log_group.agent[each.key].name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name      = "${each.key}-ErrorCount"
    namespace = "AgentCore/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "invocations" {
  for_each = var.agents

  name           = "${var.name_prefix}-${each.key}-invocations"
  log_group_name = aws_cloudwatch_log_group.agent[each.key].name
  pattern        = "{ $.eventType = \"INVOCATION_START\" }"

  metric_transformation {
    name      = "${each.key}-InvocationCount"
    namespace = "AgentCore/${var.environment}"
    value     = "1"
    unit      = "Count"
  }
}

resource "aws_cloudwatch_log_metric_filter" "latency" {
  for_each = var.agents

  name           = "${var.name_prefix}-${each.key}-latency"
  log_group_name = aws_cloudwatch_log_group.agent[each.key].name
  pattern        = "{ $.eventType = \"INVOCATION_COMPLETE\" && $.durationMs >= 0 }"

  metric_transformation {
    name      = "${each.key}-InvocationLatency"
    namespace = "AgentCore/${var.environment}"
    value     = "$.durationMs"
    unit      = "Milliseconds"
  }
}

# ------------------------------------------------------------------------------
# ALARMS - RUNTIME
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "high_error_rate" {
  for_each = var.agents

  alarm_name          = "${var.name_prefix}-${each.key}-high-error-rate"
  alarm_description   = "Error rate exceeds threshold for ${each.value.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ErrorCount"
  namespace           = "AgentCore/${var.environment}"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  dimensions = {
    AgentName = each.value.name
    AgentMode = each.value.mode
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(var.tags, {
    AgentName = each.value.name
    AlarmType = "high_error_rate"
  })
}

resource "aws_cloudwatch_metric_alarm" "high_latency" {
  for_each = { for k, v in var.agents : k => v if v.mode == "realtime" }

  alarm_name          = "${var.name_prefix}-${each.key}-high-latency"
  alarm_description   = "P95 latency exceeds threshold for ${each.value.name}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "InvocationLatency"
  namespace           = "AgentCore/${var.environment}"
  period              = 300
  extended_statistic  = "p95"
  threshold           = each.value.effective_timeout_seconds * 1000 * 0.8 # 80% of timeout
  treat_missing_data  = "notBreaching"

  dimensions = {
    AgentName = each.value.name
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(var.tags, {
    AgentName = each.value.name
    AlarmType = "high_latency"
  })
}

# ------------------------------------------------------------------------------
# ALARMS - MEMORY (if enabled)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "memory_throttling" {
  count = var.memory_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-memory-throttling"
  alarm_description   = "DynamoDB throttling detected for memory tables"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(var.tags, {
    Component = "memory"
    AlarmType = "throttling"
  })
}

# ------------------------------------------------------------------------------
# ALARMS - GATEWAY (if enabled)
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "gateway_5xx_errors" {
  count = var.gateway_enabled ? 1 : 0

  alarm_name          = "${var.name_prefix}-gateway-5xx-errors"
  alarm_description   = "API Gateway 5xx errors detected"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  treat_missing_data  = "notBreaching"

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(var.tags, {
    Component = "gateway"
    AlarmType = "5xx_errors"
  })
}

# ------------------------------------------------------------------------------
# SPLUNK FORWARDING (Kinesis Firehose)
# Only created when splunk_enabled = true
# ------------------------------------------------------------------------------

# S3 bucket for failed deliveries
resource "aws_s3_bucket" "firehose_backup" {
  count  = var.splunk_enabled ? 1 : 0
  bucket = "${var.name_prefix}-firehose-backup-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "firehose_backup" {
  count  = var.splunk_enabled ? 1 : 0
  bucket = aws_s3_bucket.firehose_backup[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_backup" {
  count  = var.splunk_enabled ? 1 : 0
  bucket = aws_s3_bucket.firehose_backup[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "firehose_backup" {
  count  = var.splunk_enabled ? 1 : 0
  bucket = aws_s3_bucket.firehose_backup[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for Firehose
resource "aws_iam_role" "firehose" {
  count = var.splunk_enabled ? 1 : 0
  name  = "${var.name_prefix}-firehose-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "firehose.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "firehose" {
  count = var.splunk_enabled ? 1 : 0
  name  = "firehose-policy"
  role  = aws_iam_role.firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.firehose_backup[0].arn,
          "${aws_s3_bucket.firehose_backup[0].arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

# Retrieve Splunk HEC token
data "aws_secretsmanager_secret_version" "splunk_token" {
  count     = var.splunk_enabled ? 1 : 0
  secret_id = var.splunk_hec_token_secret_arn
}

# Kinesis Firehose delivery stream
resource "aws_kinesis_firehose_delivery_stream" "splunk" {
  count       = var.splunk_enabled ? 1 : 0
  name        = "${var.name_prefix}-splunk-forwarder"
  destination = "splunk"

  splunk_configuration {
    hec_endpoint               = var.splunk_hec_endpoint
    hec_token                  = data.aws_secretsmanager_secret_version.splunk_token[0].secret_string
    hec_acknowledgment_timeout = 300
    retry_duration             = 3600
    s3_backup_mode             = "FailedEventsOnly"

    s3_configuration {
      role_arn           = aws_iam_role.firehose[0].arn
      bucket_arn         = aws_s3_bucket.firehose_backup[0].arn
      prefix             = "splunk-failed/"
      compression_format = "GZIP"
    }
  }

  tags = var.tags
}

# IAM role for CloudWatch to Firehose
resource "aws_iam_role" "cloudwatch_to_firehose" {
  count = var.splunk_enabled ? 1 : 0
  name  = "${var.name_prefix}-cw-to-firehose"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logs.${var.aws_region}.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "cloudwatch_to_firehose" {
  count = var.splunk_enabled ? 1 : 0
  name  = "cloudwatch-to-firehose-policy"
  role  = aws_iam_role.cloudwatch_to_firehose[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.splunk[0].arn
      }
    ]
  })
}

# Subscription filters for log forwarding
resource "aws_cloudwatch_log_subscription_filter" "splunk" {
  for_each = var.splunk_enabled ? var.agents : {}

  name            = "${var.name_prefix}-${each.key}-splunk"
  log_group_name  = aws_cloudwatch_log_group.agent[each.key].name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.splunk[0].arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose[0].arn
}

# ------------------------------------------------------------------------------
# DASHBOARD
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "agentcore" {
  count = var.dashboard_enabled ? 1 : 0

  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = concat(
      # Header
      [
        {
          type   = "text"
          x      = 0
          y      = 0
          width  = 24
          height = 1
          properties = {
            markdown = "# AgentCore Dashboard - ${var.environment}\n**Environment**: ${var.environment} | **Region**: ${var.aws_region} | **Features**: Memory=${var.memory_enabled}, Gateway=${var.gateway_enabled}, Tools=${var.tools_enabled}"
          }
        }
      ],
      # Agent metrics
      [
        for idx, agent_key in keys(var.agents) : {
          type   = "metric"
          x      = (idx % 2) * 12
          y      = 1 + floor(idx / 2) * 6
          width  = 12
          height = 6
          properties = {
            title  = "Agent: ${var.agents[agent_key].name}"
            region = var.aws_region
            metrics = [
              ["AgentCore/${var.environment}", "InvocationCount", "AgentName", var.agents[agent_key].name, { stat = "Sum", label = "Invocations" }],
              ["AgentCore/${var.environment}", "ErrorCount", "AgentName", var.agents[agent_key].name, { stat = "Sum", label = "Errors", color = "#d13212" }],
              ["AgentCore/${var.environment}", "InvocationLatency", "AgentName", var.agents[agent_key].name, { stat = "p95", label = "P95 Latency", yAxis = "right" }]
            ]
            period = 300
          }
        }
      ]
    )
  })
}

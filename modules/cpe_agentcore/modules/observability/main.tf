# ==============================================================================
# OBSERVABILITY SUBMODULE
# CloudWatch logs, metrics, alarms, and Splunk forwarding
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

resource "aws_kms_alias" "logs" {
  name          = "alias/${var.name_prefix}-logs"
  target_key_id = aws_kms_key.logs.key_id
}

# ------------------------------------------------------------------------------
# LOG GROUPS
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "agent" {
  for_each = var.agents

  name              = "${var.log_group_prefix}/${each.key}"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.logs.arn

  tags = merge(var.tags, {
    AgentName = each.value.name
    AgentKey  = each.key
  })
}

# ------------------------------------------------------------------------------
# METRIC FILTERS
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_metric_filter" "errors" {
  for_each = var.agents

  name           = "${var.name_prefix}-${each.key}-errors"
  log_group_name = aws_cloudwatch_log_group.agent[each.key].name
  pattern        = "{ $.level = \"ERROR\" }"

  metric_transformation {
    name          = "ErrorCount"
    namespace     = "AgentCore/${var.environment}"
    value         = "1"
    default_value = "0"
    dimensions = {
      AgentName = each.value.name
    }
  }
}

resource "aws_cloudwatch_log_metric_filter" "invocations" {
  for_each = var.agents

  name           = "${var.name_prefix}-${each.key}-invocations"
  log_group_name = aws_cloudwatch_log_group.agent[each.key].name
  pattern        = "{ $.eventType = \"INVOCATION_START\" }"

  metric_transformation {
    name          = "InvocationCount"
    namespace     = "AgentCore/${var.environment}"
    value         = "1"
    default_value = "0"
    dimensions = {
      AgentName = each.value.name
    }
  }
}

# ------------------------------------------------------------------------------
# ALARMS
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
  }

  alarm_actions = [var.alarm_sns_topic_arn]
  ok_actions    = [var.alarm_sns_topic_arn]

  tags = merge(var.tags, {
    AgentName = each.value.name
    AlarmType = "high_error_rate"
  })
}

# ------------------------------------------------------------------------------
# SPLUNK FORWARDING (Kinesis Firehose)
# ------------------------------------------------------------------------------

# S3 bucket for failed deliveries
resource "aws_s3_bucket" "firehose_backup" {
  bucket = "${var.name_prefix}-firehose-backup-${data.aws_caller_identity.current.account_id}"

  tags = var.tags
}

resource "aws_s3_bucket_versioning" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "firehose_backup" {
  bucket = aws_s3_bucket.firehose_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# IAM role for Firehose
resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-role"

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
  name = "firehose-policy"
  role = aws_iam_role.firehose.id

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
          aws_s3_bucket.firehose_backup.arn,
          "${aws_s3_bucket.firehose_backup.arn}/*"
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
  secret_id = var.splunk_hec_token_secret_arn
}

# Kinesis Firehose delivery stream
resource "aws_kinesis_firehose_delivery_stream" "splunk" {
  name        = "${var.name_prefix}-splunk-forwarder"
  destination = "splunk"

  splunk_configuration {
    hec_endpoint               = var.splunk_hec_endpoint
    hec_token                  = data.aws_secretsmanager_secret_version.splunk_token.secret_string
    hec_acknowledgment_timeout = 300
    retry_duration             = 3600
    s3_backup_mode             = "FailedEventsOnly"

    s3_configuration {
      role_arn           = aws_iam_role.firehose.arn
      bucket_arn         = aws_s3_bucket.firehose_backup.arn
      prefix             = "splunk-failed/"
      compression_format = "GZIP"
    }
  }

  tags = var.tags
}

# IAM role for CloudWatch to Firehose
resource "aws_iam_role" "cloudwatch_to_firehose" {
  name = "${var.name_prefix}-cw-to-firehose"

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
  name = "cloudwatch-to-firehose-policy"
  role = aws_iam_role.cloudwatch_to_firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "firehose:PutRecord",
          "firehose:PutRecordBatch"
        ]
        Resource = aws_kinesis_firehose_delivery_stream.splunk.arn
      }
    ]
  })
}

# Subscription filters for log forwarding
resource "aws_cloudwatch_log_subscription_filter" "splunk" {
  for_each = var.agents

  name            = "${var.name_prefix}-${each.key}-splunk"
  log_group_name  = aws_cloudwatch_log_group.agent[each.key].name
  filter_pattern  = ""
  destination_arn = aws_kinesis_firehose_delivery_stream.splunk.arn
  role_arn        = aws_iam_role.cloudwatch_to_firehose.arn
}

# ------------------------------------------------------------------------------
# DASHBOARD
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "agentcore" {
  count = var.dashboard_enabled ? 1 : 0

  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# AgentCore Dashboard - ${var.environment}\n**Environment**: ${var.environment} | **Region**: ${var.aws_region}"
        }
      }
    ]
  })
}


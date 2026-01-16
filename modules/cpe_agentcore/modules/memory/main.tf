# ==============================================================================
# MEMORY SUBMODULE
# Amazon Bedrock AgentCore Memory
# Provides session memory and long-term knowledge persistence
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# KMS KEY FOR MEMORY ENCRYPTION
# ------------------------------------------------------------------------------

resource "aws_kms_key" "memory" {
  description             = "${var.name_prefix}-memory-encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EnableRootPermissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "AllowAgentCoreService"
        Effect = "Allow"
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid    = "AllowExecutionRoles"
        Effect = "Allow"
        Principal = {
          AWS = [for arn in values(var.execution_role_arns) : arn]
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = merge(var.tags, {
    Purpose = "AgentCore Memory encryption"
  })
}

resource "aws_kms_alias" "memory" {
  name          = "alias/${var.name_prefix}-memory"
  target_key_id = aws_kms_key.memory.key_id
}

# ------------------------------------------------------------------------------
# SESSION MEMORY (DynamoDB)
# Short-term conversational context within sessions
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "session_memory" {
  count = var.memory_config.session_memory.enabled ? 1 : 0

  name         = "${var.name_prefix}-session-memory"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"
  range_key    = "turn_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  attribute {
    name = "turn_id"
    type = "N"
  }

  attribute {
    name = "agent_id"
    type = "S"
  }

  attribute {
    name = "created_at"
    type = "S"
  }

  # GSI for querying by agent
  global_secondary_index {
    name            = "agent-index"
    hash_key        = "agent_id"
    range_key       = "created_at"
    projection_type = "ALL"
  }

  # TTL for automatic session expiration
  ttl {
    attribute_name = "ttl"
    enabled        = true
  }

  # Server-side encryption with customer-managed key
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.memory.arn
  }

  # Point-in-time recovery for disaster recovery
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Purpose = "AgentCore session memory"
  })
}

# ------------------------------------------------------------------------------
# LONG-TERM MEMORY / KNOWLEDGE STORE
# Persistent knowledge across sessions
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "knowledge_store" {
  count = var.memory_config.long_term_memory.enabled ? 1 : 0

  name         = "${var.name_prefix}-knowledge-store"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "knowledge_id"
  range_key    = "version"

  attribute {
    name = "knowledge_id"
    type = "S"
  }

  attribute {
    name = "version"
    type = "N"
  }

  attribute {
    name = "agent_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  # GSI for querying by agent
  global_secondary_index {
    name            = "agent-index"
    hash_key        = "agent_id"
    range_key       = "knowledge_id"
    projection_type = "ALL"
  }

  # GSI for querying by category
  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    range_key       = "knowledge_id"
    projection_type = "KEYS_ONLY"
  }

  # Server-side encryption
  server_side_encryption {
    enabled     = true
    kms_key_arn = coalesce(var.memory_config.long_term_memory.encryption_key_arn, aws_kms_key.memory.arn)
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Purpose = "AgentCore long-term knowledge store"
  })
}

# ------------------------------------------------------------------------------
# S3 BUCKET FOR LARGE MEMORY OBJECTS
# Stores large context or document embeddings
# ------------------------------------------------------------------------------

resource "aws_s3_bucket" "memory_objects" {
  bucket = "${var.name_prefix}-memory-objects"

  tags = merge(var.tags, {
    Purpose = "AgentCore memory large objects"
  })
}

resource "aws_s3_bucket_versioning" "memory_objects" {
  bucket = aws_s3_bucket.memory_objects.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "memory_objects" {
  bucket = aws_s3_bucket.memory_objects.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.memory.arn
      sse_algorithm     = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "memory_objects" {
  bucket = aws_s3_bucket.memory_objects.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "memory_objects" {
  bucket = aws_s3_bucket.memory_objects.id

  rule {
    id     = "expire-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = var.memory_config.long_term_memory.retention_days
    }
  }

  rule {
    id     = "transition-to-ia"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

# ------------------------------------------------------------------------------
# MEMORY CONFIGURATION STORE
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "memory_config" {
  name        = "/${var.name_prefix}/memory/config"
  description = "AgentCore Memory configuration"
  type        = "String"
  overwrite   = true

  value = jsonencode({
    session_memory = {
      enabled            = var.memory_config.session_memory.enabled
      table_name         = var.memory_config.session_memory.enabled ? aws_dynamodb_table.session_memory[0].name : null
      table_arn          = var.memory_config.session_memory.enabled ? aws_dynamodb_table.session_memory[0].arn : null
      ttl_hours          = var.memory_config.session_memory.ttl_hours
      max_context_tokens = var.memory_config.session_memory.max_context_tokens
    }

    long_term_memory = {
      enabled        = var.memory_config.long_term_memory.enabled
      table_name     = var.memory_config.long_term_memory.enabled ? aws_dynamodb_table.knowledge_store[0].name : null
      table_arn      = var.memory_config.long_term_memory.enabled ? aws_dynamodb_table.knowledge_store[0].arn : null
      retention_days = var.memory_config.long_term_memory.retention_days
    }

    storage = {
      bucket_name = aws_s3_bucket.memory_objects.id
      bucket_arn  = aws_s3_bucket.memory_objects.arn
    }

    encryption = {
      kms_key_arn   = aws_kms_key.memory.arn
      kms_key_alias = aws_kms_alias.memory.name
    }
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# OUTPUTS LOCALS
# ------------------------------------------------------------------------------

locals {
  memory_store_arns = merge(
    var.memory_config.session_memory.enabled ? {
      session = aws_dynamodb_table.session_memory[0].arn
    } : {},
    var.memory_config.long_term_memory.enabled ? {
      knowledge = aws_dynamodb_table.knowledge_store[0].arn
    } : {},
    {
      objects = aws_s3_bucket.memory_objects.arn
    }
  )

  endpoint_url = "https://bedrock-agentcore.${var.aws_region}.amazonaws.com/memory"
}

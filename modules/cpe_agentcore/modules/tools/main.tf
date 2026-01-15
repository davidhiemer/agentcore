# ==============================================================================
# TOOLS SUBMODULE
# Amazon Bedrock AgentCore Tools
# Code Interpreter and Browser Tool configuration
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# CODE INTERPRETER CONFIGURATION
# Sandboxed code execution environment
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "code_interpreter" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  name              = "/aws/agentcore/${var.environment}/code-interpreter"
  retention_in_days = 30

  tags = merge(var.tags, {
    Purpose = "AgentCore Code Interpreter logs"
  })
}

# S3 bucket for code interpreter artifacts
resource "aws_s3_bucket" "code_interpreter" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  bucket = "${var.name_prefix}-code-interpreter"

  tags = merge(var.tags, {
    Purpose = "AgentCore Code Interpreter artifacts"
  })
}

resource "aws_s3_bucket_versioning" "code_interpreter" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  bucket = aws_s3_bucket.code_interpreter[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "code_interpreter" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  bucket = aws_s3_bucket.code_interpreter[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "code_interpreter" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  bucket = aws_s3_bucket.code_interpreter[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "code_interpreter" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  bucket = aws_s3_bucket.code_interpreter[0].id

  rule {
    id     = "expire-execution-artifacts"
    status = "Enabled"

    expiration {
      days = 7
    }

    filter {
      prefix = "executions/"
    }
  }
}

# Code Interpreter SSM configuration
resource "aws_ssm_parameter" "code_interpreter_config" {
  count = var.tools_config.code_interpreter.enabled ? 1 : 0

  name        = "/${var.name_prefix}/tools/code-interpreter/config"
  description = "AgentCore Code Interpreter configuration"
  type        = "String"

  value = jsonencode({
    enabled               = var.tools_config.code_interpreter.enabled
    languages             = var.tools_config.code_interpreter.languages
    max_execution_seconds = var.tools_config.code_interpreter.max_execution_seconds
    memory_mb             = var.tools_config.code_interpreter.memory_mb
    allow_network         = var.tools_config.code_interpreter.allow_network

    storage = {
      bucket_name = aws_s3_bucket.code_interpreter[0].id
      bucket_arn  = aws_s3_bucket.code_interpreter[0].arn
    }

    logging = {
      log_group_name = aws_cloudwatch_log_group.code_interpreter[0].name
      log_group_arn  = aws_cloudwatch_log_group.code_interpreter[0].arn
    }
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# BROWSER TOOL CONFIGURATION
# Secure web interaction capabilities
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "browser_tool" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  name              = "/aws/agentcore/${var.environment}/browser-tool"
  retention_in_days = 30

  tags = merge(var.tags, {
    Purpose = "AgentCore Browser Tool logs"
  })
}

# S3 bucket for browser tool artifacts (screenshots, content)
resource "aws_s3_bucket" "browser_tool" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  bucket = "${var.name_prefix}-browser-tool"

  tags = merge(var.tags, {
    Purpose = "AgentCore Browser Tool artifacts"
  })
}

resource "aws_s3_bucket_versioning" "browser_tool" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  bucket = aws_s3_bucket.browser_tool[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "browser_tool" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  bucket = aws_s3_bucket.browser_tool[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "browser_tool" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  bucket = aws_s3_bucket.browser_tool[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "browser_tool" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  bucket = aws_s3_bucket.browser_tool[0].id

  rule {
    id     = "expire-browser-artifacts"
    status = "Enabled"

    expiration {
      days = 1
    }

    filter {
      prefix = "sessions/"
    }
  }
}

# Browser Tool domain allowlist stored in SSM
resource "aws_ssm_parameter" "browser_tool_config" {
  count = var.tools_config.browser_tool.enabled ? 1 : 0

  name        = "/${var.name_prefix}/tools/browser-tool/config"
  description = "AgentCore Browser Tool configuration"
  type        = "String"

  value = jsonencode({
    enabled            = var.tools_config.browser_tool.enabled
    allowed_domains    = var.tools_config.browser_tool.allowed_domains
    blocked_domains    = var.tools_config.browser_tool.blocked_domains
    max_page_size_mb   = var.tools_config.browser_tool.max_page_size_mb
    screenshot_enabled = var.tools_config.browser_tool.screenshot_enabled

    storage = {
      bucket_name = aws_s3_bucket.browser_tool[0].id
      bucket_arn  = aws_s3_bucket.browser_tool[0].arn
    }

    logging = {
      log_group_name = aws_cloudwatch_log_group.browser_tool[0].name
      log_group_arn  = aws_cloudwatch_log_group.browser_tool[0].arn
    }
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# TOOLS MASTER CONFIGURATION
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "tools_config" {
  name        = "/${var.name_prefix}/tools/config"
  description = "AgentCore Tools master configuration"
  type        = "String"

  value = jsonencode({
    code_interpreter = {
      enabled = var.tools_config.code_interpreter.enabled
      arn     = var.tools_config.code_interpreter.enabled ? local.code_interpreter_arn : null
    }

    browser_tool = {
      enabled = var.tools_config.browser_tool.enabled
      arn     = var.tools_config.browser_tool.enabled ? local.browser_tool_arn : null
    }

    gateway_arn = var.gateway_arn
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# OUTPUTS LOCALS
# ------------------------------------------------------------------------------

locals {
  code_interpreter_arn = var.tools_config.code_interpreter.enabled ? (
    "arn:aws:bedrock-agentcore:${var.aws_region}:${data.aws_caller_identity.current.account_id}:code-interpreter/${var.name_prefix}"
  ) : null

  code_interpreter_endpoint_url = var.tools_config.code_interpreter.enabled ? (
    "https://bedrock-agentcore.${var.aws_region}.amazonaws.com/code-interpreter"
  ) : null

  browser_tool_arn = var.tools_config.browser_tool.enabled ? (
    "arn:aws:bedrock-agentcore:${var.aws_region}:${data.aws_caller_identity.current.account_id}:browser/${var.name_prefix}"
  ) : null

  browser_tool_endpoint_url = var.tools_config.browser_tool.enabled ? (
    "https://bedrock-agentcore.${var.aws_region}.amazonaws.com/browser"
  ) : null

  tools_arns = merge(
    var.tools_config.code_interpreter.enabled ? {
      code_interpreter = local.code_interpreter_arn
    } : {},
    var.tools_config.browser_tool.enabled ? {
      browser_tool = local.browser_tool_arn
    } : {}
  )
}


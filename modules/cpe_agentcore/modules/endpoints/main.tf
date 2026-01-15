# ==============================================================================
# ENDPOINTS SUBMODULE
# Amazon Bedrock AgentCore Runtime Endpoints
# Provides versioned endpoints for agent invocation
# ==============================================================================

# ------------------------------------------------------------------------------
# AGENTCORE ENDPOINT CONFIGURATION
# Creates endpoints pinned to specific runtime versions
# ------------------------------------------------------------------------------

# SSM Parameter to store endpoint configuration
resource "aws_ssm_parameter" "endpoint_config" {
  for_each = var.agents

  name        = "/${var.name_prefix}/endpoints/${each.key}/config"
  description = "AgentCore Endpoint configuration for ${each.value.name}"
  type        = "String"

  value = jsonencode({
    agent_key  = each.key
    agent_name = each.value.name

    endpoint = {
      id      = "${var.name_prefix}-${each.key}-endpoint"
      version = "v1"
      alias   = "live"
    }

    runtime = {
      arn = var.runtime_arns[each.key]
      id  = var.runtime_ids[each.key]
    }

    container = {
      digest = each.value.container_image_digest
    }

    invocation = {
      url = "https://bedrock-agentcore-runtime.${var.aws_region}.amazonaws.com/agents/${var.name_prefix}-${each.key}/invoke"
    }
  })

  tags = merge(var.tags, each.value.effective_tags)
}

# ------------------------------------------------------------------------------
# ENDPOINT ALIASES
# Support for versioned access patterns (live, canary, etc.)
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "endpoint_alias_live" {
  for_each = var.agents

  name        = "/${var.name_prefix}/endpoints/${each.key}/aliases/live"
  description = "Live alias for ${each.value.name} endpoint"
  type        = "String"

  value = jsonencode({
    alias   = "live"
    version = "v1"
    runtime_arn = var.runtime_arns[each.key]
    container_digest = each.value.container_image_digest
    updated_at = timestamp()
  })

  tags = merge(var.tags, each.value.effective_tags)

  lifecycle {
    ignore_changes = [value]
  }
}

# ------------------------------------------------------------------------------
# CROSS-ACCOUNT ENDPOINT ACCESS
# Resource policy for cross-account invocation
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "endpoint_access_policy" {
  count = var.cross_account_access.enabled ? 1 : 0

  name        = "/${var.name_prefix}/endpoints/access-policy"
  description = "Cross-account access policy for AgentCore endpoints"
  type        = "String"

  value = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCrossAccountInvoke"
        Effect = "Allow"
        Principal = {
          AWS = [
            for account in var.cross_account_access.allowed_caller_accounts :
            "arn:aws:iam::${account}:root"
          ]
        }
        Action = [
          "bedrock-agentcore:InvokeAgent",
          "bedrock-agentcore:InvokeAgentWithResponseStream"
        ]
        Resource = [
          for k, v in var.agents :
          "arn:aws:bedrock-agentcore:${var.aws_region}:${data.aws_caller_identity.current.account_id}:endpoint/${var.name_prefix}-${k}/*"
        ]
      }
    ]
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# PLACEHOLDER RESOURCES FOR OUTPUTS
# Replace with actual AgentCore endpoint resources when available
# ------------------------------------------------------------------------------

locals {
  endpoint_arns = {
    for k, v in var.agents : k =>
    "arn:aws:bedrock-agentcore:${var.aws_region}:${data.aws_caller_identity.current.account_id}:endpoint/${var.name_prefix}-${k}"
  }

  endpoint_ids = {
    for k, v in var.agents : k => "${var.name_prefix}-${k}-endpoint"
  }

  endpoint_urls = {
    for k, v in var.agents : k =>
    "https://bedrock-agentcore-runtime.${var.aws_region}.amazonaws.com/agents/${var.name_prefix}-${k}/invoke"
  }
}

data "aws_caller_identity" "current" {}

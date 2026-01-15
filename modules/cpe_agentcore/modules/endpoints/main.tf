# ==============================================================================
# ENDPOINTS SUBMODULE
# Amazon Bedrock AgentCore Endpoint Policies
# Manages cross-account access and endpoint versioning/aliases
#
# Note: The actual aws_bedrockagentcore_agent_runtime_endpoint resources
# are created in the runtime module. This module handles:
# - Cross-account access policies
# - Endpoint aliases for versioning
# - Endpoint metadata storage
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# ENDPOINT ALIASES
# Support for versioned access patterns (live, canary, etc.)
# Stored in SSM for easy lookup by calling applications
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "endpoint_alias_live" {
  for_each = var.agents

  name        = "/${var.name_prefix}/endpoints/${each.key}/aliases/live"
  description = "Live alias for ${each.value.name} endpoint"
  type        = "String"

  value = jsonencode({
    alias            = "live"
    version          = "v1"
    endpoint_arn     = var.endpoint_arns[each.key]
    endpoint_url     = var.endpoint_urls[each.key]
    runtime_arn      = var.runtime_arns[each.key]
    container_digest = each.value.container_image_digest
    updated_at       = timestamp()
  })

  tags = merge(var.tags, each.value.effective_tags)

  lifecycle {
    ignore_changes = [value]
  }
}

# ------------------------------------------------------------------------------
# ENDPOINT CONFIGURATION STORE
# Full endpoint configuration for discovery
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "endpoint_config" {
  for_each = var.agents

  name        = "/${var.name_prefix}/endpoints/${each.key}/config"
  description = "AgentCore Endpoint configuration for ${each.value.name}"
  type        = "String"

  value = jsonencode({
    agent_key  = each.key
    agent_name = each.value.name

    endpoint = {
      arn = var.endpoint_arns[each.key]
      url = var.endpoint_urls[each.key]
    }

    runtime = {
      arn = var.runtime_arns[each.key]
      id  = var.runtime_ids[each.key]
    }

    container = {
      digest = each.value.container_image_digest
    }

    mode = each.value.mode
  })

  tags = merge(var.tags, each.value.effective_tags)
}

# ------------------------------------------------------------------------------
# CROSS-ACCOUNT ENDPOINT ACCESS POLICY
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
          "bedrock-agentcore:InvokeAgentRuntime",
          "bedrock-agentcore:InvokeAgentRuntimeWithResponseStream"
        ]
        Resource = values(var.endpoint_arns)
      }
    ]
  })

  tags = var.tags
}

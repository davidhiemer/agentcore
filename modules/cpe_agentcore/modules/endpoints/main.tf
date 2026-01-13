# ==============================================================================
# ENDPOINTS SUBMODULE
# AgentCore Runtime Endpoints (pinned to specific versions/digests)
# ==============================================================================

# Note: This module manages the endpoint configuration that pins agents
# to specific runtime versions/digests for deterministic deployments

locals {
  # Create endpoint configurations for each agent
  endpoint_configs = {
    for agent_key, agent in var.agents : agent_key => {
      name        = "${var.name_prefix}-endpoint-${agent_key}"
      runtime_arn = var.runtime_arns[agent_key]
      digest      = agent.runtime_version_digest
      tags        = agent.effective_tags
    }
  }
}

# AgentCore runtime endpoint configuration
# This is a placeholder - actual resource will depend on AgentCore GA API
# The key concept is pinning to a specific digest for deterministic behavior

resource "aws_ssm_parameter" "endpoint_config" {
  for_each = local.endpoint_configs

  name        = "/${var.name_prefix}/endpoints/${each.key}/config"
  description = "Endpoint configuration for ${each.key}"
  type        = "String"

  value = jsonencode({
    agent_key          = each.key
    runtime_arn        = each.value.runtime_arn
    pinned_digest      = each.value.digest
    endpoint_name      = each.value.name
    created_at         = timestamp()
    environment        = var.environment
  })

  tags = merge(var.tags, each.value.tags)

  lifecycle {
    ignore_changes = [value]  # Managed via explicit updates only
  }
}

# Track deployed versions for audit trail
resource "aws_ssm_parameter" "version_history" {
  for_each = local.endpoint_configs

  name        = "/${var.name_prefix}/endpoints/${each.key}/version"
  description = "Current deployed version for ${each.key}"
  type        = "String"
  value       = each.value.digest

  tags = merge(var.tags, each.value.tags)
}


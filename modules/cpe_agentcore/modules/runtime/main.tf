# ==============================================================================
# RUNTIME SUBMODULE
# Amazon Bedrock AgentCore Runtime resources
# Deploys containerized agents to the AgentCore serverless runtime
# 
# Reference: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# CLOUDWATCH LOG GROUPS FOR RUNTIME
# ------------------------------------------------------------------------------

resource "aws_cloudwatch_log_group" "agent_runtime" {
  for_each = var.agents

  name              = "/aws/agentcore/${var.environment}/runtime/${each.key}"
  retention_in_days = 30

  tags = merge(var.tags, each.value.effective_tags)
}

# ------------------------------------------------------------------------------
# AGENTCORE AGENT RUNTIME
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagentcore_agent_runtime
# ------------------------------------------------------------------------------

resource "aws_bedrockagentcore_agent_runtime" "agent" {
  for_each = var.agents

  agent_runtime_name = "${var.name_prefix}-${each.key}"
  description        = each.value.description

  # Container configuration - references ECR image by digest
  agent_runtime_artifact {
    container_configuration {
      container_uri = "${var.ecr_repository_urls[each.key]}@${each.value.container_image_digest}"
    }
  }

  # Execution role for the agent
  role_arn = var.execution_role_arns[each.key]

  # VPC configuration for network isolation
  network_configuration {
    network_mode = "VPC"
  }

  # Runtime compute configuration
  # Note: Actual attribute names may vary - check provider docs
  # memory_size_mb = each.value.effective_memory_mb
  # timeout_seconds = each.value.effective_timeout_seconds

  tags = each.value.effective_tags
}

# ------------------------------------------------------------------------------
# AGENTCORE AGENT RUNTIME ENDPOINT
# Creates invocable endpoints for each agent runtime
# ------------------------------------------------------------------------------

resource "aws_bedrockagentcore_agent_runtime_endpoint" "agent" {
  for_each = var.agents

  name        = "${var.name_prefix}-${each.key}-endpoint"
  description = "Endpoint for ${each.value.name}"

  # Reference the agent runtime
  agent_runtime_arn = aws_bedrockagentcore_agent_runtime.agent[each.key].arn

  tags = each.value.effective_tags
}

# ------------------------------------------------------------------------------
# SSM PARAMETER FOR RUNTIME METADATA
# Stores additional configuration not in the resource
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "runtime_config" {
  for_each = var.agents

  name        = "/${var.name_prefix}/runtime/${each.key}/config"
  description = "AgentCore Runtime configuration metadata for ${each.value.name}"
  type        = "String"

  value = jsonencode({
    agent_key   = each.key
    agent_name  = each.value.name
    description = each.value.description

    runtime = {
      arn  = aws_bedrockagentcore_agent_runtime.agent[each.key].arn
      mode = each.value.mode
    }

    endpoint = {
      arn = aws_bedrockagentcore_agent_runtime_endpoint.agent[each.key].arn
    }

    container = {
      image_digest   = each.value.container_image_digest
      repository_url = var.ecr_repository_urls[each.key]
    }

    features = {
      memory_enabled  = each.value.memory_enabled
      gateway_enabled = each.value.gateway_enabled
      tools_enabled   = each.value.tools_enabled
    }

    identity = {
      provider_arn = var.identity_provider_arn
    }
  })

  tags = merge(var.tags, each.value.effective_tags)
}

# ------------------------------------------------------------------------------
# OUTPUTS LOCALS
# ------------------------------------------------------------------------------

locals {
  runtime_arns = {
    for k, v in aws_bedrockagentcore_agent_runtime.agent : k => v.arn
  }

  runtime_ids = {
    for k, v in aws_bedrockagentcore_agent_runtime.agent : k => v.id
  }

  runtime_status = {
    for k, v in aws_bedrockagentcore_agent_runtime.agent : k => v.status
  }

  endpoint_arns = {
    for k, v in aws_bedrockagentcore_agent_runtime_endpoint.agent : k => v.arn
  }

  endpoint_urls = {
    for k, v in aws_bedrockagentcore_agent_runtime_endpoint.agent : k => v.endpoint_url
  }
}

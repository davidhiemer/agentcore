# ==============================================================================
# RUNTIME SUBMODULE
# Amazon Bedrock AgentCore Runtime resources
# Deploys containerized agents to the AgentCore serverless runtime
#
# NOTE: VPC mode is configured via AWS CLI because the Terraform provider
# doesn't yet support the full VPC configuration schema
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
# Created without network config, then updated to VPC mode via CLI
# ------------------------------------------------------------------------------

resource "aws_bedrockagentcore_agent_runtime" "agent" {
  for_each = var.agents

  agent_runtime_name = replace("${var.name_prefix}_${each.key}", "-", "_")
  description        = each.value.description

  # Container configuration - references ECR image by tag
  # Note: Using :latest tag instead of @digest as AgentCore may not support digest references
  agent_runtime_artifact {
    container_configuration {
      container_uri = "${var.ecr_repository_urls[each.key]}:latest"
    }
  }

  # Execution role for the agent
  role_arn = var.execution_role_arns[each.key]

  # Network configuration - required by provider
  # We set PUBLIC here but immediately update to VPC mode via AWS CLI
  # because the Terraform provider doesn't support VPC mode config schema
  network_configuration {
    network_mode = "PUBLIC"
  }

  tags = each.value.effective_tags

  lifecycle {
    ignore_changes = [
      # Ignore network_configuration changes as we manage VPC mode via CLI
      network_configuration
    ]
  }
}

# ------------------------------------------------------------------------------
# VPC MODE CONFIGURATION VIA AWS CLI
# Required for banking security - ensures no public internet exposure
# ------------------------------------------------------------------------------

resource "null_resource" "vpc_mode_config" {
  for_each = var.agents

  triggers = {
    runtime_id     = aws_bedrockagentcore_agent_runtime.agent[each.key].agent_runtime_id
    subnet_ids     = join(",", var.subnet_ids)
    security_group = var.security_group_id
  }

  provisioner "local-exec" {
    command = <<-EOT
      aws bedrock-agentcore-control update-agent-runtime `
        --agent-runtime-id "${aws_bedrockagentcore_agent_runtime.agent[each.key].agent_runtime_id}" `
        --agent-runtime-artifact '{"containerConfiguration":{"containerUri":"${var.ecr_repository_urls[each.key]}:latest"}}' `
        --role-arn "${var.execution_role_arns[each.key]}" `
        --network-configuration '{"networkMode":"VPC","networkModeConfig":{"vpcConfig":{"subnetIds":${jsonencode(var.subnet_ids)},"securityGroupIds":["${var.security_group_id}"]}}}' `
        --region "${var.aws_region}"
    EOT

    interpreter = ["PowerShell", "-Command"]
  }

  depends_on = [aws_bedrockagentcore_agent_runtime.agent]
}

# ------------------------------------------------------------------------------
# AGENTCORE AGENT RUNTIME ENDPOINT
# Creates invocable endpoints for each agent runtime
# ------------------------------------------------------------------------------

resource "aws_bedrockagentcore_agent_runtime_endpoint" "agent" {
  for_each = var.agents

  name        = replace("${var.name_prefix}_${each.key}_endpoint", "-", "_")
  description = "Endpoint for ${each.value.name}"

  agent_runtime_id = aws_bedrockagentcore_agent_runtime.agent[each.key].agent_runtime_id

  tags = each.value.effective_tags

  depends_on = [null_resource.vpc_mode_config]
}

# ------------------------------------------------------------------------------
# SSM PARAMETER FOR RUNTIME METADATA
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "runtime_config" {
  for_each = var.agents

  name        = "/${var.name_prefix}/runtime/${each.key}/config"
  description = "AgentCore Runtime configuration metadata for ${each.value.name}"
  type        = "String"
  overwrite   = true

  value = jsonencode({
    agent_key   = each.key
    agent_name  = each.value.name
    description = each.value.description

    runtime = {
      arn  = aws_bedrockagentcore_agent_runtime.agent[each.key].agent_runtime_arn
      id   = aws_bedrockagentcore_agent_runtime.agent[each.key].agent_runtime_id
      mode = each.value.mode
    }

    endpoint = {
      arn = aws_bedrockagentcore_agent_runtime_endpoint.agent[each.key].agent_runtime_endpoint_arn
    }

    container = {
      image_digest   = each.value.container_image_digest
      repository_url = var.ecr_repository_urls[each.key]
    }

    network = {
      mode               = "VPC"
      subnet_ids         = var.subnet_ids
      security_group_ids = [var.security_group_id]
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

  depends_on = [null_resource.vpc_mode_config]
}

# ------------------------------------------------------------------------------
# OUTPUTS LOCALS
# ------------------------------------------------------------------------------

locals {
  runtime_arns = {
    for k, v in aws_bedrockagentcore_agent_runtime.agent : k => v.agent_runtime_arn
  }

  runtime_ids = {
    for k, v in aws_bedrockagentcore_agent_runtime.agent : k => v.agent_runtime_id
  }

  runtime_status = {
    for k, v in aws_bedrockagentcore_agent_runtime.agent : k => try(v.agent_runtime_status, "UNKNOWN")
  }

  endpoint_arns = {
    for k, v in aws_bedrockagentcore_agent_runtime_endpoint.agent : k => v.agent_runtime_endpoint_arn
  }

  endpoint_urls = {
    for k, v in aws_bedrockagentcore_agent_runtime_endpoint.agent : k => null
  }
}

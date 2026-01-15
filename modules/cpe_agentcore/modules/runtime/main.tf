# ==============================================================================
# RUNTIME SUBMODULE
# Amazon Bedrock AgentCore Runtime resources
# Deploys containerized agents to the AgentCore serverless runtime
# ==============================================================================

# ------------------------------------------------------------------------------
# AGENTCORE RUNTIME CONFIGURATION
# Creates runtime configurations for each agent
# Note: Using awscc provider for AgentCore resources when available
# ------------------------------------------------------------------------------

# AgentCore Runtime for each agent
# The actual resource names may differ based on the AgentCore GA release
resource "aws_cloudwatch_log_group" "agent_runtime" {
  for_each = var.agents

  name              = "/aws/agentcore/${var.environment}/runtime/${each.key}"
  retention_in_days = 30

  tags = merge(var.tags, each.value.effective_tags)
}

# SSM Parameter to store runtime configuration
# This will be replaced by actual AgentCore resources when awscc provider supports them
resource "aws_ssm_parameter" "runtime_config" {
  for_each = var.agents

  name        = "/${var.name_prefix}/runtime/${each.key}/config"
  description = "AgentCore Runtime configuration for ${each.value.name}"
  type        = "String"

  value = jsonencode({
    agent_key   = each.key
    agent_name  = each.value.name
    description = each.value.description

    container = {
      image_digest   = each.value.container_image_digest
      repository_url = var.ecr_repository_urls[each.key]
      full_image     = "${var.ecr_repository_urls[each.key]}@${each.value.container_image_digest}"
    }

    runtime = {
      mode            = each.value.mode
      memory_mb       = each.value.effective_memory_mb
      timeout_seconds = each.value.effective_timeout_seconds
      concurrency     = each.value.effective_concurrency
    }

    vpc = {
      vpc_id            = var.vpc_id
      subnet_ids        = var.subnet_ids
      security_group_id = var.security_group_id
    }

    iam = {
      execution_role_arn = var.execution_role_arns[each.key]
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
# AGENTCORE RUNTIME RESOURCES (awscc provider)
# Uncomment when AgentCore resources are available in the awscc provider
# ------------------------------------------------------------------------------

# resource "awscc_bedrock_agentcore_runtime" "agent" {
#   for_each = var.agents
#
#   name        = "${var.name_prefix}-${each.key}"
#   description = each.value.description
#
#   container_config {
#     image_uri = "${var.ecr_repository_urls[each.key]}@${each.value.container_image_digest}"
#   }
#
#   execution_role_arn = var.execution_role_arns[each.key]
#
#   runtime_config {
#     mode            = each.value.mode
#     memory_mb       = each.value.effective_memory_mb
#     timeout_seconds = each.value.effective_timeout_seconds
#     concurrency     = each.value.effective_concurrency
#   }
#
#   vpc_config {
#     vpc_id             = var.vpc_id
#     subnet_ids         = var.subnet_ids
#     security_group_ids = [var.security_group_id]
#   }
#
#   identity_config {
#     provider_arn = var.identity_provider_arn
#   }
#
#   logging_config {
#     log_group_arn = aws_cloudwatch_log_group.agent_runtime[each.key].arn
#   }
#
#   tags = [
#     for k, v in each.value.effective_tags : {
#       key   = k
#       value = v
#     }
#   ]
# }

# ------------------------------------------------------------------------------
# PLACEHOLDER RESOURCES FOR OUTPUTS
# These simulate the expected outputs from AgentCore Runtime resources
# Replace with actual resource references when awscc provider supports them
# ------------------------------------------------------------------------------

locals {
  # Simulated runtime ARNs - replace with actual resource ARNs
  runtime_arns = {
    for k, v in var.agents : k => "arn:aws:bedrock-agentcore:${var.aws_region}:${data.aws_caller_identity.current.account_id}:runtime/${var.name_prefix}-${k}"
  }

  runtime_ids = {
    for k, v in var.agents : k => "${var.name_prefix}-${k}"
  }

  runtime_status = {
    for k, v in var.agents : k => "CONFIGURED"
  }
}

data "aws_caller_identity" "current" {}

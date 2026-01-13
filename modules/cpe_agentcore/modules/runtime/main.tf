# ==============================================================================
# RUNTIME SUBMODULE
# AgentCore Runtime resources (VPC-attached)
# Uses awscc provider for AgentCore resources
# ==============================================================================

terraform {
  required_providers {
    awscc = {
      source = "hashicorp/awscc"
    }
  }
}

# AgentCore Runtime (using awscc provider)
# Note: Resource names are illustrative - actual awscc resource names may differ
# based on the AgentCore GA release
resource "awscc_bedrock_agent" "agent" {
  for_each = var.agents

  agent_name        = "${var.name_prefix}-${each.key}"
  description       = each.value.description
  agent_resource_role_arn = var.execution_role_arns[each.key]

  # Foundation model configuration
  foundation_model = "anthropic.claude-3-sonnet-20240229-v1:0"

  # Idle session timeout
  idle_session_ttl_in_seconds = 1800

  # Instruction for the agent
  instruction = each.value.description

  tags = [
    for k, v in each.value.effective_tags : {
      key   = k
      value = v
    }
  ]
}

# Agent Alias for versioned access
resource "awscc_bedrock_agent_alias" "agent" {
  for_each = var.agents

  agent_alias_name = "live"
  agent_id         = awscc_bedrock_agent.agent[each.key].agent_id
  description      = "Live alias for ${each.value.name}"

  tags = [
    for k, v in each.value.effective_tags : {
      key   = k
      value = v
    }
  ]
}


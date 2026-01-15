# ==============================================================================
# GATEWAY SUBMODULE
# Amazon Bedrock AgentCore Gateway
# Tool governance, rate limiting, and external API connectivity
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# TOOL REGISTRY (DynamoDB)
# Stores tool definitions and configurations
# ------------------------------------------------------------------------------

resource "aws_dynamodb_table" "tool_registry" {
  name         = "${var.name_prefix}-tool-registry"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "tool_id"

  attribute {
    name = "tool_id"
    type = "S"
  }

  attribute {
    name = "category"
    type = "S"
  }

  global_secondary_index {
    name            = "category-index"
    hash_key        = "category"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Purpose = "AgentCore Gateway tool registry"
  })
}

# ------------------------------------------------------------------------------
# CONNECTIONS SECRETS
# Stores connection credentials securely
# ------------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "connections" {
  for_each = var.gateway_config.connections

  name        = "${var.name_prefix}/gateway/connections/${each.key}"
  description = "Connection credentials for ${each.value.name}"

  tags = merge(var.tags, {
    Purpose    = "AgentCore Gateway connection"
    Connection = each.key
  })
}

# ------------------------------------------------------------------------------
# API GATEWAY FOR TOOL EXECUTION
# Provides rate limiting and access control
# ------------------------------------------------------------------------------

resource "aws_api_gateway_rest_api" "gateway" {
  name        = "${var.name_prefix}-gateway"
  description = "AgentCore Gateway API for tool execution"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

resource "aws_api_gateway_resource" "tools" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_rest_api.gateway.root_resource_id
  path_part   = "tools"
}

resource "aws_api_gateway_resource" "tool_invoke" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id
  parent_id   = aws_api_gateway_resource.tools.id
  path_part   = "{toolId}"
}

resource "aws_api_gateway_method" "tool_invoke" {
  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  resource_id   = aws_api_gateway_resource.tool_invoke.id
  http_method   = "POST"
  authorization = "AWS_IAM"
}

# ------------------------------------------------------------------------------
# USAGE PLANS FOR RATE LIMITING
# Per-agent rate limiting configuration
# ------------------------------------------------------------------------------

resource "aws_api_gateway_usage_plan" "agent_plans" {
  for_each = var.agents

  name        = "${var.name_prefix}-${each.key}-usage"
  description = "Usage plan for agent ${each.value.name}"

  api_stages {
    api_id = aws_api_gateway_rest_api.gateway.id
    stage  = aws_api_gateway_stage.gateway.stage_name
  }

  quota_settings {
    limit  = 10000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = try(var.gateway_config.tool_policies[each.key].rate_limit.burst_limit, 100)
    rate_limit  = try(var.gateway_config.tool_policies[each.key].rate_limit.requests_per_minute, 1000) / 60
  }

  tags = merge(var.tags, each.value.effective_tags)
}

resource "aws_api_gateway_deployment" "gateway" {
  rest_api_id = aws_api_gateway_rest_api.gateway.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.tools.id,
      aws_api_gateway_resource.tool_invoke.id,
      aws_api_gateway_method.tool_invoke.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "gateway" {
  deployment_id = aws_api_gateway_deployment.gateway.id
  rest_api_id   = aws_api_gateway_rest_api.gateway.id
  stage_name    = var.environment

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.gateway_access.arn
    format = jsonencode({
      requestId         = "$context.requestId"
      ip                = "$context.identity.sourceIp"
      caller            = "$context.identity.caller"
      user              = "$context.identity.user"
      requestTime       = "$context.requestTime"
      httpMethod        = "$context.httpMethod"
      resourcePath      = "$context.resourcePath"
      status            = "$context.status"
      protocol          = "$context.protocol"
      responseLength    = "$context.responseLength"
      integrationLatency = "$context.integrationLatency"
    })
  }

  xray_tracing_enabled = true

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "gateway_access" {
  name              = "/aws/apigateway/${var.name_prefix}-gateway"
  retention_in_days = 30

  tags = var.tags
}

# ------------------------------------------------------------------------------
# TOOL POLICIES CONFIGURATION
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "tool_policies" {
  for_each = var.gateway_config.tool_policies

  name        = "/${var.name_prefix}/gateway/policies/${each.key}"
  description = "Tool policy for ${each.value.tool_name}"
  type        = "String"

  value = jsonencode({
    tool_name      = each.value.tool_name
    allowed_agents = each.value.allowed_agents
    rate_limit     = each.value.rate_limit
    timeout_seconds = each.value.timeout_seconds
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# GATEWAY CONFIGURATION
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "gateway_config" {
  name        = "/${var.name_prefix}/gateway/config"
  description = "AgentCore Gateway configuration"
  type        = "String"

  value = jsonencode({
    enabled = true
    environment = var.environment

    api_gateway = {
      id          = aws_api_gateway_rest_api.gateway.id
      arn         = aws_api_gateway_rest_api.gateway.arn
      endpoint    = aws_api_gateway_stage.gateway.invoke_url
      stage       = aws_api_gateway_stage.gateway.stage_name
    }

    tool_registry = {
      table_name = aws_dynamodb_table.tool_registry.name
      table_arn  = aws_dynamodb_table.tool_registry.arn
    }

    connections = {
      for k, v in var.gateway_config.connections : k => {
        name         = v.name
        endpoint_url = v.endpoint_url
        auth_type    = v.auth_type
        secret_arn   = aws_secretsmanager_secret.connections[k].arn
      }
    }

    tool_policies = var.gateway_config.tool_policies
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# OUTPUTS LOCALS
# ------------------------------------------------------------------------------

locals {
  gateway_arn  = aws_api_gateway_rest_api.gateway.arn
  endpoint_url = aws_api_gateway_stage.gateway.invoke_url

  tool_registry = {
    for policy_key, policy in var.gateway_config.tool_policies : policy_key => {
      tool_name      = policy.tool_name
      allowed_agents = policy.allowed_agents
    }
  }

  connection_ids = {
    for k, v in aws_secretsmanager_secret.connections : k => v.id
  }
}

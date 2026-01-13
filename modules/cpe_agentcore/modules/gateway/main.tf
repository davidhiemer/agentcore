# ==============================================================================
# GATEWAY SUBMODULE (Future - Feature-flagged)
# Tool governance and connectivity
# ==============================================================================

# This module is a placeholder for future AgentCore Gateway functionality
# It will manage tool governance, rate limiting, and connectivity controls

# Placeholder resource to prevent empty module errors
resource "aws_ssm_parameter" "gateway_config" {
  name        = "/${var.name_prefix}/gateway/config"
  description = "Gateway configuration placeholder"
  type        = "String"
  value       = jsonencode({
    enabled     = true
    environment = var.environment
    created_at  = timestamp()
  })

  tags = var.tags

  lifecycle {
    ignore_changes = [value]
  }
}


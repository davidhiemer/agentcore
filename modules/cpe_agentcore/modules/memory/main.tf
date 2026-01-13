# ==============================================================================
# MEMORY SUBMODULE (Future - Feature-flagged)
# AgentCore Memory for persistent agent context
# ==============================================================================

# This module is a placeholder for future AgentCore Memory functionality
# It will manage persistent memory stores for agents

# Placeholder resource to prevent empty module errors
resource "aws_ssm_parameter" "memory_config" {
  name        = "/${var.name_prefix}/memory/config"
  description = "Memory configuration placeholder"
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


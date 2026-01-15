# ==============================================================================
# TERRAFORM VERSION AND PROVIDER REQUIREMENTS
# Amazon Bedrock AgentCore Platform
# ==============================================================================

terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.17.0" # Required for aws_bedrockagentcore_* resources
    }
  }
}

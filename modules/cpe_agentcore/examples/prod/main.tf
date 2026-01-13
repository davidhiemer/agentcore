# ==============================================================================
# PROD ENVIRONMENT EXAMPLE
# ==============================================================================

terraform {
  required_version = ">= 1.6.0"

  backend "s3" {
    bucket         = "bank-terraform-state-prod"
    key            = "agentcore/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

module "agentcore" {
  source = "../../"

  environment    = var.environment
  aws_region     = var.aws_region
  aws_account_id = var.aws_account_id

  vpc_config           = var.vpc_config
  scale_profile        = var.scale_profile
  agents               = var.agents
  cross_account_access = var.cross_account_access
  observability_config = var.observability_config
  tags                 = var.tags
}

# ==============================================================================
# OUTPUTS
# ==============================================================================

output "ecr_repository_urls" {
  value = module.agentcore.ecr_repository_urls
}

output "execution_role_arns" {
  value = module.agentcore.execution_role_arns
}

output "endpoint_ids" {
  value = module.agentcore.endpoint_ids
}

output "log_group_names" {
  value = module.agentcore.log_group_names
}

output "summary" {
  value = module.agentcore.summary
}


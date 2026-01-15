# ==============================================================================
# IDENTITY SUBMODULE
# Amazon Bedrock AgentCore Identity
# Enterprise identity provider integration for agent authentication
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# COGNITO USER POOL (if using Cognito)
# ------------------------------------------------------------------------------

resource "aws_cognito_user_pool" "agentcore" {
  count = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? 1 : 0

  name = "${var.name_prefix}-identity"

  # Password policy
  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }

  # MFA configuration
  mfa_configuration = "ON"

  software_token_mfa_configuration {
    enabled = true
  }

  # Account recovery
  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  # User attributes
  schema {
    name                     = "email"
    attribute_data_type      = "String"
    developer_only_attribute = false
    mutable                  = true
    required                 = true

    string_attribute_constraints {
      min_length = 1
      max_length = 256
    }
  }

  # Advanced security
  user_pool_add_ons {
    advanced_security_mode = "ENFORCED"
  }

  tags = merge(var.tags, {
    Purpose = "AgentCore Identity"
  })
}

resource "aws_cognito_user_pool_client" "agentcore" {
  count = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? 1 : 0

  name         = "${var.name_prefix}-client"
  user_pool_id = aws_cognito_user_pool.agentcore[0].id

  generate_secret = true

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH"
  ]

  # Token validity
  access_token_validity  = 1   # hours
  id_token_validity      = 1   # hours
  refresh_token_validity = 30  # days

  token_validity_units {
    access_token  = "hours"
    id_token      = "hours"
    refresh_token = "days"
  }

  # Prevent user existence errors
  prevent_user_existence_errors = "ENABLED"
}

resource "aws_cognito_user_pool_domain" "agentcore" {
  count = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? 1 : 0

  domain       = "${var.name_prefix}-auth"
  user_pool_id = aws_cognito_user_pool.agentcore[0].id
}

# ------------------------------------------------------------------------------
# OIDC IDENTITY PROVIDER (for Entra ID, Okta)
# ------------------------------------------------------------------------------

resource "aws_cognito_identity_provider" "oidc" {
  count = var.identity_config.enabled && contains(["entra_id", "okta"], var.identity_config.provider.type) ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.agentcore[0].id
  provider_name = var.identity_config.provider.type == "entra_id" ? "EntraID" : "Okta"
  provider_type = "OIDC"

  provider_details = {
    authorize_scopes          = "openid profile email"
    client_id                 = var.identity_config.provider.client_id
    client_secret             = data.aws_secretsmanager_secret_version.oidc_client_secret[0].secret_string
    oidc_issuer               = var.identity_config.provider.issuer_url
    attributes_request_method = "GET"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
  }
}

data "aws_secretsmanager_secret_version" "oidc_client_secret" {
  count = var.identity_config.enabled && contains(["entra_id", "okta"], var.identity_config.provider.type) ? 1 : 0

  secret_id = var.identity_config.provider.client_secret_arn
}

# ------------------------------------------------------------------------------
# SAML IDENTITY PROVIDER
# ------------------------------------------------------------------------------

resource "aws_cognito_identity_provider" "saml" {
  count = var.identity_config.enabled && var.identity_config.provider.type == "saml" ? 1 : 0

  user_pool_id  = aws_cognito_user_pool.agentcore[0].id
  provider_name = "SAML"
  provider_type = "SAML"

  provider_details = {
    MetadataURL = var.identity_config.provider.metadata_url
  }

  attribute_mapping = {
    email    = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress"
    username = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier"
    name     = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
  }
}

# ------------------------------------------------------------------------------
# AGENT GROUPS (for role mappings)
# ------------------------------------------------------------------------------

resource "aws_cognito_user_group" "agent_access" {
  for_each = var.identity_config.enabled ? var.identity_config.role_mappings : {}

  name         = each.key
  user_pool_id = aws_cognito_user_pool.agentcore[0].id
  description  = "Access to agents: ${join(", ", each.value.agent_keys)}"
}

# ------------------------------------------------------------------------------
# IDENTITY CONFIGURATION STORE
# ------------------------------------------------------------------------------

resource "aws_ssm_parameter" "identity_config" {
  count = var.identity_config.enabled ? 1 : 0

  name        = "/${var.name_prefix}/identity/config"
  description = "AgentCore Identity configuration"
  type        = "SecureString"

  value = jsonencode({
    enabled = var.identity_config.enabled

    provider = {
      type       = var.identity_config.provider.type
      issuer_url = var.identity_config.provider.type == "cognito" ? "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.agentcore[0].id}" : var.identity_config.provider.issuer_url
    }

    cognito = var.identity_config.provider.type == "cognito" ? {
      user_pool_id     = aws_cognito_user_pool.agentcore[0].id
      user_pool_arn    = aws_cognito_user_pool.agentcore[0].arn
      client_id        = aws_cognito_user_pool_client.agentcore[0].id
      domain           = aws_cognito_user_pool_domain.agentcore[0].domain
      endpoint         = "https://${aws_cognito_user_pool_domain.agentcore[0].domain}.auth.${var.aws_region}.amazoncognito.com"
    } : null

    role_mappings = var.identity_config.role_mappings

    agents = {
      for k, v in var.agents : k => {
        name           = v.name
        allowed_groups = [for rm_key, rm in var.identity_config.role_mappings : rm_key if contains(rm.agent_keys, k)]
      }
    }
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# OUTPUTS LOCALS
# ------------------------------------------------------------------------------

locals {
  provider_arn = var.identity_config.enabled ? (
    var.identity_config.provider.type == "cognito" ?
    aws_cognito_user_pool.agentcore[0].arn :
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(var.identity_config.provider.issuer_url, "https://", "")}"
  ) : null

  endpoint_url = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? (
    "https://${aws_cognito_user_pool_domain.agentcore[0].domain}.auth.${var.aws_region}.amazoncognito.com"
  ) : var.identity_config.provider.issuer_url

  user_pool_id = var.identity_config.enabled && var.identity_config.provider.type == "cognito" ? (
    aws_cognito_user_pool.agentcore[0].id
  ) : null
}


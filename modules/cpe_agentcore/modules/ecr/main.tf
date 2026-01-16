# ==============================================================================
# ECR SUBMODULE
# Manages ECR repositories for agent container images
# ==============================================================================

resource "aws_ecr_repository" "agent" {
  for_each = var.agents

  name                 = "${var.name_prefix}/${each.key}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }

  tags = merge(var.tags, {
    AgentName = each.value.name
    AgentKey  = each.key
  })
}

# KMS key for ECR encryption
resource "aws_kms_key" "ecr" {
  description             = "${var.name_prefix}-ecr-encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "Enable IAM User Permissions"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      },
      {
        Sid    = "Allow ECR Service"
        Effect = "Allow"
        Principal = {
          Service = "ecr.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "Allow Bedrock AgentCore Service"
        Effect = "Allow"
        Principal = {
          Service = "bedrock-agentcore.amazonaws.com"
        }
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "random_id" "ecr_key_suffix" {
  byte_length = 4
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.name_prefix}-ecr-${random_id.ecr_key_suffix.hex}"
  target_key_id = aws_kms_key.ecr.key_id
}

# ECR lifecycle policy for cost management
resource "aws_ecr_lifecycle_policy" "agent" {
  for_each   = var.agents
  repository = aws_ecr_repository.agent[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 30 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Repository policy for Bedrock AgentCore service access
resource "aws_ecr_repository_policy" "agent" {
  for_each   = var.agents
  repository = aws_ecr_repository.agent[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid    = "AllowBedrockAgentCorePull"
          Effect = "Allow"
          Principal = {
            Service = "bedrock-agentcore.amazonaws.com"
          }
          Action = [
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchCheckLayerAvailability"
          ]
          Condition = {
            StringEquals = {
              "aws:SourceAccount" = data.aws_caller_identity.current.account_id
            }
          }
        }
      ],
      var.cross_account_access.enabled ? [
        {
          Sid    = "AllowCrossAccountPull"
          Effect = "Allow"
          Principal = {
            AWS = [for account in var.cross_account_access.allowed_caller_accounts : "arn:aws:iam::${account}:root"]
          }
          Action = [
            "ecr:BatchGetImage",
            "ecr:GetDownloadUrlForLayer"
          ]
        }
      ] : []
    )
  })
}

data "aws_caller_identity" "current" {}



# ==============================================================================
# IAM SUBMODULE
# Execution roles, capability bundles, and permission boundaries
# ==============================================================================

data "aws_caller_identity" "current" {}

# ------------------------------------------------------------------------------
# PERMISSION BOUNDARY
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "permission_boundary" {
  name        = var.permission_boundary_name
  description = "Permission boundary for AgentCore execution roles"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Allowed actions (maximum envelope)
      {
        Sid    = "AllowedServices"
        Effect = "Allow"
        Action = [
          # Observability
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
          "cloudwatch:PutMetricData",
          "xray:PutTraceSegments",
          "xray:PutTelemetryRecords",
          "xray:GetSamplingRules",
          "xray:GetSamplingTargets",

          # Storage
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectTagging",
          "s3:PutObject",
          "s3:PutObjectTagging",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",

          # Database
          "dynamodb:GetItem",
          "dynamodb:BatchGetItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:DescribeTable",

          # Secrets
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",

          # Encryption
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:GenerateDataKeyWithoutPlaintext",
          "kms:DescribeKey",

          # Messaging
          "sns:Publish",
          "sqs:SendMessage",
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:GetQueueUrl",

          # Compute
          "lambda:InvokeFunction",

          # AI
          "bedrock:InvokeModel",
          "bedrock:InvokeModelWithResponseStream"
        ]
        Resource = "*"
      },

      # Explicit denies
      {
        Sid    = "DenyIAMChanges"
        Effect = "Deny"
        Action = [
          "iam:*",
          "organizations:*",
          "account:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenySecurityServices"
        Effect = "Deny"
        Action = [
          "cloudtrail:*",
          "config:*",
          "guardduty:*",
          "securityhub:*",
          "inspector:*"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyNetworkChanges"
        Effect = "Deny"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress"
        ]
        Resource = "*"
      },
      {
        Sid    = "DenyDataExfiltration"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:PutBucketPolicy",
          "dynamodb:DeleteTable",
          "rds:DeleteDBInstance",
          "rds:DeleteDBCluster"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

# ------------------------------------------------------------------------------
# EXECUTION ROLES (One per agent)
# ------------------------------------------------------------------------------

resource "aws_iam_role" "agent_execution" {
  for_each = var.agents

  name                 = "${var.name_prefix}-agent-exec-${each.key}"
  permissions_boundary = aws_iam_policy.permission_boundary.arn

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "bedrock.amazonaws.com"
        }
        Action = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = var.aws_account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:bedrock:${var.aws_region}:${var.aws_account_id}:agent/*"
          }
        }
      }
    ]
  })

  tags = merge(var.tags, {
    AgentName = each.value.name
    AgentKey  = each.key
  })
}

# ------------------------------------------------------------------------------
# CAPABILITY BUNDLES
# ------------------------------------------------------------------------------

resource "aws_iam_policy" "capability_bundle" {
  for_each = local.capability_bundle_definitions

  name   = "${var.name_prefix}-capability-${each.key}"
  policy = jsonencode(each.value)

  tags = merge(var.tags, {
    CapabilityBundle = each.key
  })
}

# Attach capability bundles to each role
resource "aws_iam_role_policy_attachment" "capability_bundles" {
  for_each = {
    for pair in flatten([
      for agent_key, agent in var.agents : [
        for bundle in agent.capability_bundles : {
          key       = "${agent_key}-${bundle}"
          agent_key = agent_key
          bundle    = bundle
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.agent_execution[each.value.agent_key].name
  policy_arn = aws_iam_policy.capability_bundle[each.value.bundle].arn
}

# Attach custom policies if specified
resource "aws_iam_role_policy_attachment" "custom_policies" {
  for_each = {
    for pair in flatten([
      for agent_key, agent in var.agents : [
        for policy_arn in coalesce(agent.custom_policy_arns, []) : {
          key        = "${agent_key}-${md5(policy_arn)}"
          agent_key  = agent_key
          policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.agent_execution[each.value.agent_key].name
  policy_arn = each.value.policy_arn
}


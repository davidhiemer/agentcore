# ==============================================================================
# CAPABILITY BUNDLE DEFINITIONS
# For Amazon Bedrock AgentCore Platform
# ==============================================================================

locals {
  capability_bundle_definitions = {
    # =========================================================================
    # BASELINE - Required for all agents
    # =========================================================================
    baseline = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "CloudWatchLogs"
          Effect = "Allow"
          Action = [
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "logs:DescribeLogStreams"
          ]
          Resource = [
            "arn:aws:logs:${var.aws_region}:${var.aws_account_id}:log-group:/aws/agentcore/${var.environment}/*"
          ]
        },
        {
          Sid    = "XRayTracing"
          Effect = "Allow"
          Action = [
            "xray:PutTraceSegments",
            "xray:PutTelemetryRecords",
            "xray:GetSamplingRules",
            "xray:GetSamplingTargets"
          ]
          Resource = "*"
        },
        {
          Sid    = "CloudWatchMetrics"
          Effect = "Allow"
          Action = [
            "cloudwatch:PutMetricData"
          ]
          Resource = "*"
          Condition = {
            StringEquals = {
              "cloudwatch:namespace" = "AgentCore/${var.environment}"
            }
          }
        },
        {
          Sid    = "ECRPull"
          Effect = "Allow"
          Action = [
            "ecr:GetAuthorizationToken"
          ]
          Resource = "*"
        },
        {
          Sid    = "ECRPullImages"
          Effect = "Allow"
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage"
          ]
          Resource = [
            "arn:aws:ecr:${var.aws_region}:${var.aws_account_id}:repository/${var.name_prefix}/*"
          ]
        }
      ]
    }

    # =========================================================================
    # S3 READ-ONLY
    # =========================================================================
    s3_readonly = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "S3ReadOnly"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetObjectTagging",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            "arn:aws:s3:::${var.name_prefix}-*",
            "arn:aws:s3:::${var.name_prefix}-*/*"
          ]
        }
      ]
    }

    # =========================================================================
    # S3 READ-WRITE
    # =========================================================================
    s3_readwrite = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "S3ReadWrite"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetObjectTagging",
            "s3:PutObject",
            "s3:PutObjectTagging",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            "arn:aws:s3:::${var.name_prefix}-*",
            "arn:aws:s3:::${var.name_prefix}-*/*"
          ]
        }
      ]
    }

    # =========================================================================
    # DYNAMODB READ-ONLY
    # =========================================================================
    dynamodb_readonly = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DynamoDBReadOnly"
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:BatchGetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:DescribeTable"
          ]
          Resource = [
            "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.name_prefix}-*",
            "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.name_prefix}-*/index/*"
          ]
        }
      ]
    }

    # =========================================================================
    # DYNAMODB READ-WRITE
    # =========================================================================
    dynamodb_readwrite = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "DynamoDBReadWrite"
          Effect = "Allow"
          Action = [
            "dynamodb:GetItem",
            "dynamodb:BatchGetItem",
            "dynamodb:Query",
            "dynamodb:Scan",
            "dynamodb:PutItem",
            "dynamodb:UpdateItem",
            "dynamodb:DeleteItem",
            "dynamodb:BatchWriteItem",
            "dynamodb:DescribeTable"
          ]
          Resource = [
            "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.name_prefix}-*",
            "arn:aws:dynamodb:${var.aws_region}:${var.aws_account_id}:table/${var.name_prefix}-*/index/*"
          ]
        }
      ]
    }

    # =========================================================================
    # SECRETS MANAGER READ-ONLY
    # =========================================================================
    secrets_readonly = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "SecretsReadOnly"
          Effect = "Allow"
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ]
          Resource = [
            "arn:aws:secretsmanager:${var.aws_region}:${var.aws_account_id}:secret:${var.name_prefix}/*"
          ]
        }
      ]
    }

    # =========================================================================
    # SSM PARAMETERS READ-ONLY
    # =========================================================================
    ssm_parameters_readonly = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "SSMParametersReadOnly"
          Effect = "Allow"
          Action = [
            "ssm:GetParameter",
            "ssm:GetParameters",
            "ssm:GetParametersByPath"
          ]
          Resource = [
            "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/${var.name_prefix}/*"
          ]
        }
      ]
    }

    # =========================================================================
    # KMS ENCRYPT/DECRYPT
    # =========================================================================
    kms_encrypt_decrypt = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "KMSEncryptDecrypt"
          Effect = "Allow"
          Action = [
            "kms:Encrypt",
            "kms:Decrypt",
            "kms:GenerateDataKey",
            "kms:GenerateDataKeyWithoutPlaintext",
            "kms:DescribeKey"
          ]
          Resource = [
            "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/*"
          ]
          Condition = {
            StringEquals = {
              "kms:ViaService" = [
                "s3.${var.aws_region}.amazonaws.com",
                "secretsmanager.${var.aws_region}.amazonaws.com",
                "dynamodb.${var.aws_region}.amazonaws.com",
                "bedrock-agentcore.${var.aws_region}.amazonaws.com"
              ]
            }
          }
        }
      ]
    }

    # =========================================================================
    # SNS PUBLISH
    # =========================================================================
    sns_publish = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "SNSPublish"
          Effect = "Allow"
          Action = [
            "sns:Publish"
          ]
          Resource = [
            "arn:aws:sns:${var.aws_region}:${var.aws_account_id}:${var.name_prefix}-*"
          ]
        }
      ]
    }

    # =========================================================================
    # SQS SEND/RECEIVE
    # =========================================================================
    sqs_send_receive = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "SQSSendReceive"
          Effect = "Allow"
          Action = [
            "sqs:SendMessage",
            "sqs:ReceiveMessage",
            "sqs:DeleteMessage",
            "sqs:GetQueueAttributes",
            "sqs:GetQueueUrl"
          ]
          Resource = [
            "arn:aws:sqs:${var.aws_region}:${var.aws_account_id}:${var.name_prefix}-*"
          ]
        }
      ]
    }

    # =========================================================================
    # LAMBDA INVOKE
    # =========================================================================
    lambda_invoke = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "LambdaInvoke"
          Effect = "Allow"
          Action = [
            "lambda:InvokeFunction"
          ]
          Resource = [
            "arn:aws:lambda:${var.aws_region}:${var.aws_account_id}:function:${var.name_prefix}-*"
          ]
        }
      ]
    }

    # =========================================================================
    # BEDROCK INVOKE MODEL
    # =========================================================================
    bedrock_invoke_model = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "BedrockInvokeModel"
          Effect = "Allow"
          Action = [
            "bedrock:InvokeModel",
            "bedrock:InvokeModelWithResponseStream"
          ]
          Resource = [
            "arn:aws:bedrock:${var.aws_region}::foundation-model/*",
            "arn:aws:bedrock:${var.aws_region}:${var.aws_account_id}:provisioned-model/*",
            "arn:aws:bedrock:${var.aws_region}:${var.aws_account_id}:inference-profile/*"
          ]
        }
      ]
    }

    # =========================================================================
    # AGENTCORE MEMORY
    # Access to AgentCore Memory APIs
    # =========================================================================
    agentcore_memory = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AgentCoreMemory"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:GetSessionMemory",
            "bedrock-agentcore:PutSessionMemory",
            "bedrock-agentcore:DeleteSessionMemory",
            "bedrock-agentcore:GetKnowledge",
            "bedrock-agentcore:PutKnowledge",
            "bedrock-agentcore:QueryKnowledge"
          ]
          Resource = [
            "arn:aws:bedrock-agentcore:${var.aws_region}:${var.aws_account_id}:memory/*"
          ]
        }
      ]
    }

    # =========================================================================
    # AGENTCORE GATEWAY
    # Access to AgentCore Gateway APIs
    # =========================================================================
    agentcore_gateway = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AgentCoreGateway"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:InvokeTool",
            "bedrock-agentcore:ListTools",
            "bedrock-agentcore:GetToolDefinition"
          ]
          Resource = [
            "arn:aws:bedrock-agentcore:${var.aws_region}:${var.aws_account_id}:gateway/*"
          ]
        }
      ]
    }

    # =========================================================================
    # AGENTCORE TOOLS
    # Access to Code Interpreter and Browser Tool
    # =========================================================================
    agentcore_tools = {
      Version = "2012-10-17"
      Statement = [
        {
          Sid    = "AgentCoreCodeInterpreter"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:ExecuteCode",
            "bedrock-agentcore:GetCodeExecutionResult"
          ]
          Resource = [
            "arn:aws:bedrock-agentcore:${var.aws_region}:${var.aws_account_id}:code-interpreter/*"
          ]
        },
        {
          Sid    = "AgentCoreBrowserTool"
          Effect = "Allow"
          Action = [
            "bedrock-agentcore:BrowseUrl",
            "bedrock-agentcore:GetPageContent",
            "bedrock-agentcore:TakeScreenshot"
          ]
          Resource = [
            "arn:aws:bedrock-agentcore:${var.aws_region}:${var.aws_account_id}:browser/*"
          ]
        }
      ]
    }
  }
}

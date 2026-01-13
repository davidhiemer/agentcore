# CPE AgentCore Terraform Module

A production-ready Terraform module for deploying Amazon Bedrock AgentCore across multiple AWS accounts (dev, preprod, prod) with banking-grade security, auditability, and operational controls.

## Overview

This module implements a VPC-attached AgentCore platform with:
- **One root module** with internal submodules (not independently consumable)
- **Environment parity** - identical architecture across all environments
- **Scale profiles** - all environment differences expressed via variables
- **Least privilege IAM** - per-agent execution roles with capability bundles
- **Digest-based deployments** - immutable artifact references for auditability
- **Full observability** - CloudWatch + Splunk integration

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         cpe_agentcore (Root)                        │
├─────────────────────────────────────────────────────────────────────┤
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌─────────────┐   │
│  │   ecr   │ │ network │ │   iam   │ │ runtime │ │  endpoints  │   │
│  └─────────┘ └─────────┘ └─────────┘ └─────────┘ └─────────────┘   │
│  ┌─────────────────┐ ┌─────────────┐ ┌─────────────┐               │
│  │  observability  │ │   gateway   │ │   memory    │               │
│  │                 │ │  (future)   │ │  (future)   │               │
│  └─────────────────┘ └─────────────┘ └─────────────┘               │
└─────────────────────────────────────────────────────────────────────┘
```

## Quick Start

```hcl
module "agentcore" {
  source = "path/to/cpe_agentcore"

  environment    = "dev"
  aws_region     = "us-east-1"
  aws_account_id = "111111111111"

  vpc_config = {
    vpc_id = "vpc-12345"
    private_subnet_ids = {
      "us-east-1a" = {
        subnet_id         = "subnet-1a"
        availability_zone = "us-east-1a"
        cidr_block        = "10.0.1.0/24"
      }
      # ... more subnets
    }
    security_group_ids = {
      agentcore_runtime  = "sg-runtime"
      vpc_endpoints      = "sg-vpce"
      nat_gateway_egress = "sg-nat"
    }
    route_table_ids = {
      "us-east-1a" = "rtb-1a"
    }
  }

  scale_profile = {
    nat_mode                       = "single"  # "per_az" for prod
    vpc_endpoint_az_count          = 1
    runtime_concurrency_limit      = 10
    runtime_memory_mb              = 512
    runtime_timeout_seconds        = 60
    log_retention_days             = 30
    metrics_resolution_seconds     = 60
    alarm_evaluation_periods       = 3
    tool_execution_timeout_seconds = 30
    tool_max_concurrent_executions = 5
    enable_gateway                 = false
    enable_memory                  = false
  }

  agents = {
    "my-agent" = {
      name                   = "My Agent"
      description            = "Agent description"
      runtime_version_digest = "sha256:abc123..."
      capability_bundles     = ["baseline", "bedrock_invoke_model"]
    }
  }

  observability_config = {
    splunk_hec_endpoint         = "https://splunk:8088"
    splunk_hec_token_secret_arn = "arn:aws:secretsmanager:..."
    alarm_sns_topic_arn         = "arn:aws:sns:..."
    enable_xray_tracing         = true
    dashboard_enabled           = true
  }
}
```

## Submodules

| Submodule | Purpose |
|-----------|---------|
| `ecr` | ECR repositories for agent container images |
| `network` | VPC endpoints, NAT gateways, private DNS |
| `iam` | Execution roles, capability bundles, permission boundaries |
| `runtime` | AgentCore Runtime resources (VPC-attached) |
| `endpoints` | Runtime endpoints pinned to specific digests |
| `observability` | CloudWatch logs/metrics/alarms, Splunk forwarding |
| `gateway` | (Future) Tool governance and connectivity |
| `memory` | (Future) AgentCore Memory |

## Scale Profile

The `scale_profile` object controls all environment-specific configuration:

| Parameter | Dev | Preprod | Prod |
|-----------|-----|---------|------|
| `nat_mode` | single | per_az | per_az |
| `vpc_endpoint_az_count` | 1 | 2 | 3 |
| `runtime_concurrency_limit` | 10 | 100 | 1000 |
| `log_retention_days` | 30 | 180 | 365 |
| `metrics_resolution_seconds` | 60 | 60 | 1 |

## Capability Bundles

Pre-defined IAM capability bundles for agents:

| Bundle | Permissions |
|--------|-------------|
| `baseline` | CloudWatch Logs, X-Ray, CloudWatch Metrics |
| `s3_readonly` | S3 GetObject, ListBucket |
| `s3_readwrite` | S3 read + PutObject, DeleteObject |
| `dynamodb_readonly` | DynamoDB GetItem, Query, Scan |
| `dynamodb_readwrite` | DynamoDB read + PutItem, UpdateItem, DeleteItem |
| `secrets_readonly` | Secrets Manager GetSecretValue |
| `ssm_parameters_readonly` | SSM Parameter Store read |
| `kms_encrypt_decrypt` | KMS Encrypt, Decrypt, GenerateDataKey |
| `sns_publish` | SNS Publish |
| `sqs_send_receive` | SQS SendMessage, ReceiveMessage |
| `lambda_invoke` | Lambda InvokeFunction |
| `bedrock_invoke_model` | Bedrock InvokeModel |

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.6.0, < 2.0.0 |
| aws | >= 5.40.0, < 6.0.0 |
| awscc | >= 1.0.0, < 2.0.0 |

## Inputs

See [variables.tf](./variables.tf) for full documentation.

## Outputs

| Name | Description |
|------|-------------|
| `ecr_repository_urls` | Map of agent key to ECR URL |
| `execution_role_arns` | Map of agent key to IAM role ARN |
| `endpoint_ids` | Map of agent key to endpoint ID |
| `log_group_names` | Map of agent key to CloudWatch log group |
| `summary` | Deployment summary |

## Architecture Documentation

- [Target Architecture](../architecture/01-target-architecture.md)
- [Terraform Module Design](../architecture/02-terraform-module-design.md)
- [Scale Profile](../architecture/03-scale-profile.md)
- [Artifact Promotion](../architecture/04-artifact-promotion.md)
- [Network Design](../architecture/05-network-design.md)
- [IAM Model](../architecture/06-iam-model.md)
- [Observability](../architecture/07-observability.md)
- [Runbook](../architecture/08-runbook.md)

## License

Internal use only - Bank Platform Engineering


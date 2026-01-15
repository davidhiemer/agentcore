# Amazon Bedrock AgentCore Platform - Requirements Specification

## Executive Summary

You are an AWS platform architect designing a production-ready **Amazon Bedrock AgentCore** platform across three AWS accounts (dev, preprod, prod). Each account is "prod-like" and must be architecturally identical; only sizing/scale knobs may vary per account. We are a bank and require high auditability, least privilege, and deterministic behavior. All infrastructure must be in Terraform.

> **IMPORTANT**: This platform is built on **Amazon Bedrock AgentCore** — a distinct service from the legacy "Bedrock Agents" (`awscc_bedrock_agent`). AgentCore provides a serverless runtime for containerized AI agents with integrated memory, identity, gateway, and tool execution capabilities.

---

## AgentCore Platform Components

The platform must implement ALL AgentCore components as Terraform submodules:

| Component | Description | Submodule |
|-----------|-------------|-----------|
| **AgentCore Runtime** | Serverless environment for deploying containerized agents. Supports real-time invocations and async workloads up to 8 hours. | `modules/runtime` |
| **AgentCore Memory** | Short-term conversational context + long-term knowledge persistence across sessions. | `modules/memory` |
| **AgentCore Identity** | Enterprise identity provider integration (Cognito, Microsoft Entra ID, Okta). | `modules/identity` |
| **AgentCore Gateway** | Secure tool access governance, rate limiting, API connectivity controls. | `modules/gateway` |
| **AgentCore Code Interpreter** | Sandboxed code execution environment for agents. | `modules/tools` |
| **AgentCore Browser Tool** | Secure, model-agnostic web interaction capabilities. | `modules/tools` |
| **AgentCore Observability** | Real-time dashboards, metrics, distributed tracing, Splunk forwarding. | `modules/observability` |

---

## Container-Based Agent Deployment Model

Agents are packaged as container images and deployed to AgentCore Runtime:

1. **Build**: Agent code is containerized with a Dockerfile
2. **Sign**: Container image is signed with Sigstore/cosign
3. **Attest**: SBOM generated and attached as attestation
4. **Store**: Pushed to Artifactory (source of truth)
5. **Promote**: Copied by digest to per-account ECR repositories
6. **Deploy**: AgentCore Runtime pulls image by digest from ECR
7. **Invoke**: Agents are invoked via AgentCore Endpoints

### Agent Container Requirements

Agents must expose HTTP endpoints:
- `POST /invocations` - Handle incoming agent requests
- `GET /ping` - Health check endpoint

Agents can be built with any framework (LangGraph, Strands, CrewAI, custom) as AgentCore is framework-agnostic.

---

## Core Architectural Constraints

### Single Module Design
- We are building ONE Terraform module (`cpe_agentcore`) that represents the entire AgentCore platform
- All functionality MUST be implemented as internal submodules
- Consumers must never compose multiple modules to build the platform
- Environment differences must be expressed ONLY via variables (especially `scale_profile`)
- Code must be DRY: no copy/paste per environment, no duplicated logic

### Module Structure

```
cpe_agentcore/
├── README.md
├── main.tf                    # Root orchestration
├── variables.tf               # Root input contract
├── outputs.tf                 # Root output contract
├── providers.tf               # Provider configuration
├── versions.tf                # Version constraints
├── locals.tf                  # Normalization and derived values
│
├── modules/                   # INTERNAL submodules (not independently consumable)
│   ├── ecr/                   # Container repositories and policies
│   ├── network/               # VPC endpoints, private DNS, NAT strategy
│   ├── iam/                   # Execution roles, capability bundles, permission boundaries
│   ├── runtime/               # AgentCore Runtime resources
│   ├── endpoints/             # AgentCore Runtime Endpoints (pinned digests)
│   ├── memory/                # AgentCore Memory (session + long-term)
│   ├── identity/              # AgentCore Identity (IdP integration)
│   ├── gateway/               # AgentCore Gateway (tool governance)
│   ├── tools/                 # Code Interpreter + Browser Tool
│   └── observability/         # CloudWatch, dashboards, alarms, Splunk
│
├── examples/                  # Usage examples per environment
│   ├── dev/
│   ├── preprod/
│   └── prod/
│
└── tests/                     # Terraform tests
```

### Submodule Dependency Order

```
ecr ─────────────────────────────────────────┐
                                              │
network ──────────┬───────────────────────────┤
                  │                           │
                  v                           v
              identity ──────────────────> runtime
                  │                           │
                  v                           v
              gateway ──────────────────> endpoints
                  │                           │
                  v                           v
               tools ────────────────> observability
                  │                           │
                  v                           v
              memory ─────────────────────────┘
```

---

## Submodule Specifications

### 1. ECR Submodule (`modules/ecr`)

**Purpose**: Per-account ECR repositories for agent container images.

**Requirements**:
- One repository per agent
- Image tag mutability: IMMUTABLE (enforce digest-based references)
- Encryption: KMS with customer-managed key
- Scan on push: enabled
- Lifecycle policy: retain last 30 images
- Cross-account pull access for cross-account callers (when enabled)

### 2. Network Submodule (`modules/network`)

**Purpose**: VPC endpoints, private DNS, NAT gateway strategy.

**Requirements**:
- VPC is created EXTERNALLY; module accepts VPC inputs
- NAT strategy: `per_az` (3 NAT gateways) for prod/preprod, `single` for dev
- Gateway endpoints: S3, DynamoDB
- Interface endpoints for AgentCore and AWS services:
  - `bedrock-agentcore` (Runtime API)
  - `bedrock-agentcore-runtime` (Agent invocation)
  - `bedrock-runtime` (Model invocation)
  - `ecr.api`, `ecr.dkr`
  - `logs`, `monitoring`, `xray`
  - `secretsmanager`, `ssm`, `kms`, `sts`
- Private hosted zone for cross-account private DNS resolution
- AZ-count tuning for interface endpoints (cost optimization in dev)

### 3. IAM Submodule (`modules/iam`)

**Purpose**: Execution roles, capability bundles, permission boundaries.

**Requirements**:
- One execution role per agent per environment
- Baseline permissions + opt-in capability bundles:
  - `baseline` (CloudWatch logs, X-Ray, basic runtime)
  - `s3_readonly`, `s3_readwrite`
  - `dynamodb_readonly`, `dynamodb_readwrite`
  - `secrets_readonly`
  - `ssm_parameters_readonly`
  - `kms_encrypt_decrypt`
  - `sns_publish`, `sqs_send_receive`
  - `lambda_invoke`
  - `bedrock_invoke_model`
  - `agentcore_memory` (access Memory APIs)
  - `agentcore_gateway` (access Gateway APIs)
  - `agentcore_tools` (use Code Interpreter, Browser Tool)
- Permission boundary enforced on all agent roles
- Cross-account assume role policies for callers

### 4. Runtime Submodule (`modules/runtime`)

**Purpose**: AgentCore Runtime resources for deploying containerized agents.

**Requirements**:
- Create AgentCore Runtime configuration per agent
- VPC attachment (private subnets, security groups)
- Container image reference by ECR digest (immutable)
- Concurrency limits per agent
- Timeout configuration (real-time vs async modes)
- Resource allocation (memory, CPU)
- Integration with Identity for authentication
- Integration with Memory for session/knowledge persistence
- Integration with Gateway for tool access

**Agent Configuration Schema**:
```hcl
agents = {
  "agent-key" = {
    name                   = string  # Display name
    description            = string  # Agent description
    container_image_digest = string  # sha256:... from ECR
    
    # Runtime configuration
    mode                = string  # "realtime" or "async"
    timeout_seconds     = number  # Max 300 for realtime, 28800 for async
    memory_mb           = number  # 512-10240
    concurrency_limit   = number  # Max concurrent invocations
    
    # Capability bundles
    capability_bundles  = set(string)
    
    # Feature integration
    memory_enabled      = bool    # Enable AgentCore Memory
    gateway_enabled     = bool    # Enable AgentCore Gateway
    tools_enabled       = bool    # Enable Code Interpreter/Browser
    
    # Tags
    additional_tags     = map(string)
  }
}
```

### 5. Endpoints Submodule (`modules/endpoints`)

**Purpose**: AgentCore Runtime Endpoints for agent invocation.

**Requirements**:
- One endpoint per agent (pinned to specific runtime version)
- Endpoint versioning (aliases: `live`, `canary`, version numbers)
- Cross-account invocation support via VPC endpoints
- Authentication integration (Identity)
- Request/response logging configuration

### 6. Memory Submodule (`modules/memory`)

**Purpose**: AgentCore Memory for conversation context and knowledge persistence.

**Requirements**:
- **Session Memory**: Short-term conversational context within a session
  - TTL configuration (default 24 hours)
  - Max context window size
- **Long-term Memory**: Persistent knowledge across sessions
  - Knowledge retention policies
  - Vector store integration (if applicable)
  - Encryption at rest (KMS)
- Per-agent memory isolation
- Memory access via execution role permissions
- Observability: memory usage metrics, access logs

**Memory Configuration Schema**:
```hcl
memory_config = {
  session_memory = {
    enabled            = bool
    ttl_hours          = number  # 1-168 (1 week max)
    max_context_tokens = number  # Max tokens per session
  }
  
  long_term_memory = {
    enabled            = bool
    retention_days     = number  # 30-365
    encryption_key_arn = string  # KMS key for encryption
  }
}
```

### 7. Identity Submodule (`modules/identity`)

**Purpose**: Enterprise identity provider integration for agent authentication.

**Requirements**:
- Support multiple IdP types:
  - Amazon Cognito User Pools
  - Microsoft Entra ID (Azure AD)
  - Okta
  - SAML 2.0 providers
- OAuth 2.0 / OIDC token validation
- Role mapping from IdP claims to agent permissions
- Session management
- Audit logging of authentication events

**Identity Configuration Schema**:
```hcl
identity_config = {
  enabled = bool
  
  provider = {
    type = string  # "cognito", "entra_id", "okta", "saml"
    
    # Cognito-specific
    user_pool_id     = optional(string)
    user_pool_client = optional(string)
    
    # OIDC-specific (Entra, Okta)
    issuer_url       = optional(string)
    client_id        = optional(string)
    client_secret_arn = optional(string)  # Secrets Manager ARN
    
    # SAML-specific
    metadata_url     = optional(string)
  }
  
  role_mappings = map(object({
    claim_name  = string
    claim_value = string
    agent_keys  = set(string)  # Which agents this role can invoke
  }))
}
```

### 8. Gateway Submodule (`modules/gateway`)

**Purpose**: AgentCore Gateway for tool governance and connectivity.

**Requirements**:
- **Tool Registry**: Define available tools and their configurations
- **Access Policies**: Which agents can use which tools
- **Rate Limiting**: Per-agent, per-tool rate limits
- **Connectivity**: Manage connections to external APIs/services
- **Audit Logging**: All tool invocations logged

**Gateway Configuration Schema**:
```hcl
gateway_config = {
  enabled = bool
  
  # Tool access policies
  tool_policies = map(object({
    tool_name       = string
    allowed_agents  = set(string)
    rate_limit = {
      requests_per_minute = number
      burst_limit         = number
    }
    timeout_seconds = number
  }))
  
  # External connectivity
  connections = map(object({
    name          = string
    endpoint_url  = string
    auth_type     = string  # "api_key", "oauth", "iam"
    secret_arn    = optional(string)
  }))
}
```

### 9. Tools Submodule (`modules/tools`)

**Purpose**: Code Interpreter and Browser Tool configuration.

**Requirements**:

**Code Interpreter**:
- Sandboxed execution environment
- Supported languages (Python, Node.js, etc.)
- Resource limits (CPU, memory, execution time)
- Network isolation (no outbound by default)
- File system limits

**Browser Tool**:
- Headless browser configuration
- Allowed domains list (whitelist approach)
- Request/response size limits
- Screenshot/content capture policies
- Session isolation

**Tools Configuration Schema**:
```hcl
tools_config = {
  code_interpreter = {
    enabled           = bool
    languages         = set(string)  # ["python", "nodejs"]
    max_execution_seconds = number
    memory_mb         = number
    allow_network     = bool
  }
  
  browser_tool = {
    enabled           = bool
    allowed_domains   = set(string)  # Whitelist
    blocked_domains   = set(string)  # Blacklist (takes precedence)
    max_page_size_mb  = number
    screenshot_enabled = bool
  }
}
```

### 10. Observability Submodule (`modules/observability`)

**Purpose**: Comprehensive monitoring, logging, and alerting.

**Requirements**:
- **CloudWatch Logs**: Structured JSON logs for all components
- **CloudWatch Metrics**: Runtime, memory, gateway, tool metrics
- **CloudWatch Alarms**: SLO-based alerting
- **X-Ray Tracing**: Distributed tracing across components
- **Dashboards**: Per-agent and platform-wide dashboards
- **Splunk Forwarding**: Firehose to Splunk HEC

**Log Schema** (audit-friendly):
```json
{
  "timestamp": "ISO8601",
  "trace_id": "string",
  "span_id": "string",
  "agent_id": "string",
  "agent_name": "string",
  "environment": "string",
  "event_type": "invocation|tool_call|memory_access|auth",
  "caller_identity": "string",
  "request_id": "string",
  "duration_ms": "number",
  "status": "success|error",
  "error_code": "string|null",
  "metadata": {}
}
```

**Metrics**:
- `agentcore.invocations.count`
- `agentcore.invocations.duration`
- `agentcore.invocations.errors`
- `agentcore.memory.operations`
- `agentcore.gateway.tool_calls`
- `agentcore.tools.executions`
- `agentcore.identity.auth_events`

---

## scale_profile Schema

All environment differences are expressed via `scale_profile`:

```hcl
variable "scale_profile" {
  type = object({
    # Network scaling
    nat_mode                = string  # "per_az" or "single"
    vpc_endpoint_az_count   = number  # 1-3
    
    # Runtime scaling
    runtime_concurrency_limit   = number
    runtime_memory_mb_default   = number
    runtime_timeout_seconds_default = number
    
    # Memory scaling
    memory_session_ttl_hours    = number
    memory_long_term_retention_days = number
    
    # Gateway scaling
    gateway_rate_limit_default  = number
    gateway_burst_limit_default = number
    
    # Tools scaling
    code_interpreter_max_execution_seconds = number
    code_interpreter_memory_mb = number
    browser_max_page_size_mb   = number
    
    # Observability scaling
    log_retention_days          = number
    metrics_resolution_seconds  = number
    alarm_evaluation_periods    = number
    xray_sampling_rate          = number  # 0.0-1.0
    
    # Feature flags
    enable_memory   = bool
    enable_identity = bool
    enable_gateway  = bool
    enable_tools    = bool
  })
}
```

### Example Profiles

**Dev** (cost-optimized):
```hcl
scale_profile = {
  nat_mode                = "single"
  vpc_endpoint_az_count   = 1
  runtime_concurrency_limit = 10
  log_retention_days      = 30
  xray_sampling_rate      = 1.0  # Full sampling for debugging
  enable_memory           = true
  enable_identity         = true
  enable_gateway          = true
  enable_tools            = true
}
```

**Prod** (full scale, high availability):
```hcl
scale_profile = {
  nat_mode                = "per_az"
  vpc_endpoint_az_count   = 3
  runtime_concurrency_limit = 1000
  log_retention_days      = 365
  xray_sampling_rate      = 0.05  # 5% sampling at scale
  enable_memory           = true
  enable_identity         = true
  enable_gateway          = true
  enable_tools            = true
}
```

---

## Cross-Account Invocation

**Requirements**:
- Caller accounts invoke agents via VPC interface endpoints
- Private DNS resolution (no internet traversal)
- IAM role assumption for authentication
- Optional: Identity provider tokens for user-level auth

**Configuration**:
```hcl
variable "cross_account_access" {
  type = object({
    enabled                 = bool
    allowed_caller_accounts = set(string)
    allowed_caller_roles    = map(set(string))  # account -> roles
    allowed_caller_vpc_ids  = set(string)
  })
}
```

---

## Artifact Promotion Flow

1. **Build in CI**: GitHub Actions builds container, signs with Sigstore, generates SBOM
2. **Push to Artifactory**: Signed image pushed to Artifactory (source of truth)
3. **Promote to Dev**: Copy by digest to Dev ECR (auto or manual approval)
4. **Promote to Preprod**: Copy by digest (requires Tech Lead approval)
5. **Promote to Prod**: Copy by digest (requires Platform + Security approval, 24h soak time)

**Audit Requirements**:
- Every promotion logged to S3 evidence bucket
- Build manifests include commit SHA, actor, timestamp
- Attestations verifiable via cosign
- Evidence retained: 7 years for prod, 1 year for non-prod

---

## Non-Negotiables

- Do NOT use legacy Bedrock Agents resources (`awscc_bedrock_agent`, `awscc_bedrock_agent_alias`)
- Do NOT replace AgentCore Runtime with EKS, ECS, or Lambda
- Do NOT rebuild container images per environment (copy by digest only)
- Do NOT collapse environments into Terraform workspaces
- Do NOT create separate "dev/prod" modules
- Do NOT allow tag-based container references (digest only)

---

## Hard Requirements

| Requirement | Implementation |
|-------------|----------------|
| VPC-attached runtime | Private subnets, interface endpoints, no public access |
| Artifact source of truth | Artifactory; ECR is per-account cache |
| Promotion strategy | Copy by digest only; approval gates in GitHub Actions |
| NAT strategy | Per-AZ in prod/preprod; single in dev |
| IAM model | One execution role per agent; capability bundles |
| Observability | CloudWatch + Splunk; structured JSON logs |
| State isolation | One Terraform state per account |
| Provider strategy | Use `awscc` for AgentCore resources; `aws` for supporting infra |

---

## Terraform Quality Requirements

- Strong typing for all variables with validation blocks
- Locals for normalization and derived values
- `for_each` with maps (avoid `count` where possible)
- Explicit dependencies via inputs/outputs between submodules
- All resources tagged consistently
- Provider version constraints explicit
- Submodules are NOT independently consumable

---

## Outputs Required

The root module must output:

```hcl
# ECR
output "ecr_repository_urls" { }
output "ecr_repository_arns" { }

# Network
output "vpc_endpoint_ids" { }
output "private_hosted_zone_id" { }

# IAM
output "execution_role_arns" { }
output "permission_boundary_arn" { }

# Runtime
output "runtime_arns" { }
output "runtime_ids" { }

# Endpoints
output "endpoint_arns" { }
output "endpoint_urls" { }

# Memory
output "memory_store_arns" { }
output "memory_endpoint_url" { }

# Identity
output "identity_provider_arn" { }
output "identity_endpoint_url" { }

# Gateway
output "gateway_arn" { }
output "gateway_endpoint_url" { }

# Tools
output "code_interpreter_arn" { }
output "browser_tool_arn" { }

# Observability
output "log_group_arns" { }
output "dashboard_url" { }
output "alarm_arns" { }
```

---

## Deliverables

You must produce:

1. **Target Architecture Documentation**
   - Mermaid diagrams showing all components
   - Cross-account invocation pattern
   - Artifact promotion flow

2. **Terraform Module Implementation**
   - Complete `cpe_agentcore` root module
   - All 10 internal submodules fully implemented
   - Example configurations for dev/preprod/prod

3. **scale_profile Documentation**
   - Full schema with validation
   - Example profiles per environment

4. **IAM Model**
   - Baseline role definition
   - All capability bundles
   - Permission boundary

5. **Observability**
   - Log schema
   - Dashboard definitions
   - Alarm configurations
   - Splunk forwarding

6. **Runbook**
   - Agent deployment
   - Promotion workflow
   - Rollback procedures
   - Incident response

For each major design choice, include:
- "Why this choice"
- "Why not the primary alternative"

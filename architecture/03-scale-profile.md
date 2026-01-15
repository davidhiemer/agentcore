# Scale Profile Schema

## Overview

The `scale_profile` object is the **sole mechanism** for expressing environment differences. All three environments (dev, preprod, prod) use identical Terraform code; only the values within `scale_profile` differ.

---

## Schema Definition

```hcl
variable "scale_profile" {
  description = "Environment-specific scaling configuration - the ONLY source of environment differences"
  type = object({
    # =========================================================================
    # NETWORK SCALING
    # =========================================================================
    
    # NAT Gateway strategy
    # - "per_az": One NAT Gateway per Availability Zone (HA, higher cost)
    # - "single": One NAT Gateway for all AZs (cost-optimized, single point of failure)
    nat_mode = string
    
    # Number of AZs to deploy interface VPC endpoints across
    # Range: 1-3 (cost vs availability tradeoff)
    vpc_endpoint_az_count = number

    # =========================================================================
    # RUNTIME SCALING
    # =========================================================================
    
    # Maximum concurrent agent invocations
    runtime_concurrency_limit = number
    
    # Memory allocation per agent execution (MB)
    runtime_memory_mb = number
    
    # Maximum execution time per invocation (seconds)
    runtime_timeout_seconds = number

    # =========================================================================
    # OBSERVABILITY SCALING
    # =========================================================================
    
    # CloudWatch Logs retention period (days)
    # Must be a valid CloudWatch Logs retention value
    log_retention_days = number
    
    # CloudWatch Metrics resolution (seconds)
    # 1 = high resolution (more expensive), 60 = standard
    metrics_resolution_seconds = number
    
    # Number of evaluation periods for CloudWatch alarms
    alarm_evaluation_periods = number

    # =========================================================================
    # TOOL EXECUTION SCALING
    # =========================================================================
    
    # Maximum time for tool execution (seconds)
    tool_execution_timeout_seconds = number
    
    # Maximum concurrent tool executions per agent
    tool_max_concurrent_executions = number

    # =========================================================================
    # FEATURE FLAGS
    # =========================================================================
    
    # Enable AgentCore Gateway (tool governance)
    enable_gateway = bool
    
    # Enable AgentCore Memory
    enable_memory = bool
  })
}
```

---

## Validation Rules

```hcl
variable "scale_profile" {
  # ... type definition above ...

  # ---------------------------------------------------------------------------
  # NAT Mode Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = contains(["per_az", "single"], var.scale_profile.nat_mode)
    error_message = "NAT mode must be 'per_az' or 'single'."
  }

  # ---------------------------------------------------------------------------
  # VPC Endpoint AZ Count Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.vpc_endpoint_az_count >= 1 && var.scale_profile.vpc_endpoint_az_count <= 3
    error_message = "VPC endpoint AZ count must be between 1 and 3."
  }

  # ---------------------------------------------------------------------------
  # Runtime Concurrency Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.runtime_concurrency_limit >= 1 && var.scale_profile.runtime_concurrency_limit <= 10000
    error_message = "Runtime concurrency limit must be between 1 and 10000."
  }

  # ---------------------------------------------------------------------------
  # Memory Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.runtime_memory_mb >= 128 && var.scale_profile.runtime_memory_mb <= 10240
    error_message = "Runtime memory must be between 128 and 10240 MB."
  }

  validation {
    condition     = var.scale_profile.runtime_memory_mb % 64 == 0
    error_message = "Runtime memory must be a multiple of 64 MB."
  }

  # ---------------------------------------------------------------------------
  # Timeout Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.runtime_timeout_seconds >= 1 && var.scale_profile.runtime_timeout_seconds <= 900
    error_message = "Runtime timeout must be between 1 and 900 seconds."
  }

  # ---------------------------------------------------------------------------
  # Log Retention Validation (Audit Requirement)
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.log_retention_days >= 30
    error_message = "Log retention must be at least 30 days for audit requirements."
  }

  validation {
    condition = contains(
      [30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1096, 1827, 2192, 2557, 2922, 3288, 3653],
      var.scale_profile.log_retention_days
    )
    error_message = "Log retention must be a valid CloudWatch Logs retention value."
  }

  # ---------------------------------------------------------------------------
  # Metrics Resolution Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = contains([1, 60], var.scale_profile.metrics_resolution_seconds)
    error_message = "Metrics resolution must be 1 (high resolution) or 60 (standard)."
  }

  # ---------------------------------------------------------------------------
  # Alarm Evaluation Periods Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.alarm_evaluation_periods >= 1 && var.scale_profile.alarm_evaluation_periods <= 24
    error_message = "Alarm evaluation periods must be between 1 and 24."
  }

  # ---------------------------------------------------------------------------
  # Tool Execution Validation
  # ---------------------------------------------------------------------------
  validation {
    condition     = var.scale_profile.tool_execution_timeout_seconds >= 1 && var.scale_profile.tool_execution_timeout_seconds <= 300
    error_message = "Tool execution timeout must be between 1 and 300 seconds."
  }

  validation {
    condition     = var.scale_profile.tool_max_concurrent_executions >= 1 && var.scale_profile.tool_max_concurrent_executions <= 100
    error_message = "Tool max concurrent executions must be between 1 and 100."
  }

  # ---------------------------------------------------------------------------
  # Production Environment Invariants
  # These validations can be enhanced based on environment input
  # ---------------------------------------------------------------------------
}

# Additional cross-variable validation in locals
locals {
  # Enforce production invariants
  _validate_prod_nat = var.environment == "prod" ? (
    var.scale_profile.nat_mode == "per_az" ? true : tobool("Production must use NAT per AZ")
  ) : true

  _validate_preprod_nat = var.environment == "preprod" ? (
    var.scale_profile.nat_mode == "per_az" ? true : tobool("Preprod must use NAT per AZ")
  ) : true

  _validate_prod_log_retention = var.environment == "prod" ? (
    var.scale_profile.log_retention_days >= 365 ? true : tobool("Production log retention must be at least 365 days")
  ) : true

  _validate_prod_endpoint_ha = var.environment == "prod" ? (
    var.scale_profile.vpc_endpoint_az_count >= 2 ? true : tobool("Production VPC endpoints must span at least 2 AZs")
  ) : true
}
```

---

## Environment-Specific Values

### Development (`dev`)

```hcl
# examples/dev/terraform.tfvars

environment    = "dev"
aws_region     = "us-east-1"
aws_account_id = "111111111111"

scale_profile = {
  # Network - cost-optimized, single NAT acceptable for dev
  nat_mode              = "single"
  vpc_endpoint_az_count = 1

  # Runtime - lower limits for cost savings
  runtime_concurrency_limit = 10
  runtime_memory_mb         = 512
  runtime_timeout_seconds   = 60

  # Observability - shorter retention for dev
  log_retention_days         = 30
  metrics_resolution_seconds = 60
  alarm_evaluation_periods   = 3

  # Tool execution - relaxed limits
  tool_execution_timeout_seconds = 30
  tool_max_concurrent_executions = 5

  # Feature flags - enable for testing
  enable_gateway = true
  enable_memory  = true
}
```

### Pre-Production (`preprod`)

```hcl
# examples/preprod/terraform.tfvars

environment    = "preprod"
aws_region     = "us-east-1"
aws_account_id = "222222222222"

scale_profile = {
  # Network - production-like HA configuration
  nat_mode              = "per_az"
  vpc_endpoint_az_count = 2

  # Runtime - production-like capacity, slightly lower limits
  runtime_concurrency_limit = 100
  runtime_memory_mb         = 2048
  runtime_timeout_seconds   = 300

  # Observability - production-like retention
  log_retention_days         = 180
  metrics_resolution_seconds = 60
  alarm_evaluation_periods   = 3

  # Tool execution - production-like limits
  tool_execution_timeout_seconds = 60
  tool_max_concurrent_executions = 20

  # Feature flags - match production
  enable_gateway = false
  enable_memory  = false
}
```

### Production (`prod`)

```hcl
# examples/prod/terraform.tfvars

environment    = "prod"
aws_region     = "us-east-1"
aws_account_id = "333333333333"

scale_profile = {
  # Network - full HA, all AZs
  nat_mode              = "per_az"
  vpc_endpoint_az_count = 3

  # Runtime - full production capacity
  runtime_concurrency_limit = 1000
  runtime_memory_mb         = 4096
  runtime_timeout_seconds   = 300

  # Observability - full audit retention
  log_retention_days         = 365
  metrics_resolution_seconds = 1
  alarm_evaluation_periods   = 5

  # Tool execution - production limits
  tool_execution_timeout_seconds = 120
  tool_max_concurrent_executions = 50

  # Feature flags - conservative enablement
  enable_gateway = false
  enable_memory  = false
}
```

---

## Environment Comparison Matrix

| Configuration | Dev | Preprod | Prod | Rationale |
|--------------|-----|---------|------|-----------|
| **NAT Mode** | single | per_az | per_az | Dev cost savings; prod/preprod HA required |
| **VPC Endpoint AZs** | 1 | 2 | 3 | Cost vs availability tradeoff |
| **Concurrency Limit** | 10 | 100 | 1000 | Traffic volume per environment |
| **Memory (MB)** | 512 | 2048 | 4096 | Workload complexity scaling |
| **Timeout (sec)** | 60 | 300 | 300 | Dev: fast feedback; prod: full duration |
| **Log Retention** | 30 days | 180 days | 365 days | Audit requirements by env |
| **Metrics Resolution** | 60s | 60s | 1s | High-res metrics only justified in prod |
| **Alarm Eval Periods** | 3 | 3 | 5 | More stability in prod before alerting |
| **Gateway** | true | false | false | Test new features in dev only |
| **Memory** | true | false | false | Test new features in dev only |

---

## Architectural Drift Prevention

The following patterns prevent environments from drifting architecturally:

### 1. Validation Rules in Variables

```hcl
# Prevents invalid NAT modes
validation {
  condition     = contains(["per_az", "single"], var.scale_profile.nat_mode)
  error_message = "NAT mode must be 'per_az' or 'single'."
}
```

### 2. Environment-Specific Invariants in Locals

```hcl
# Production MUST use NAT per AZ
locals {
  _validate_prod_nat = var.environment == "prod" ? (
    var.scale_profile.nat_mode == "per_az" ? true : tobool("Production must use NAT per AZ")
  ) : true
}
```

### 3. Preconditions on Resources

```hcl
resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_azs)
  
  lifecycle {
    precondition {
      condition     = !(var.environment == "prod" && var.scale_profile.nat_mode != "per_az")
      error_message = "Production environment must use NAT per AZ for HA requirements."
    }
  }
  
  # ... resource configuration
}
```

### 4. Policy-as-Code Integration

```hcl
# terraform-sentinel-policies/scale-profile-policies.sentinel

import "tfplan/v2" as tfplan

# Enforce production NAT HA
prod_nat_ha = rule {
  all tfplan.resource_changes as _, rc {
    rc.type == "module.cpe_agentcore" and
    rc.change.after.environment == "prod" implies
    rc.change.after.scale_profile.nat_mode == "per_az"
  }
}

# Enforce minimum log retention for production
prod_log_retention = rule {
  all tfplan.resource_changes as _, rc {
    rc.type == "module.cpe_agentcore" and
    rc.change.after.environment == "prod" implies
    rc.change.after.scale_profile.log_retention_days >= 365
  }
}

main = rule {
  prod_nat_ha and prod_log_retention
}
```

---

## Why This Design

### Why Single scale_profile Object
- **Chosen**: All environment differences in one typed object
- **Why**: Clear contract; validates as a unit; prevents scattered conditionals; documents all knobs in one place
- **Why not multiple variables**: Harder to validate relationships; easier to miss configurations; less discoverable

### Why Strict Validation Rules
- **Chosen**: Multiple validation blocks with clear error messages
- **Why**: Fail fast; prevent invalid deployments; document invariants as code; reduces review burden
- **Why not loose validation**: Invalid configurations could reach deployment; harder to debug; increases audit risk

### Why Environment-Specific Invariants in Locals
- **Chosen**: Cross-variable validation using local tobool trick
- **Why**: Catches violations at plan time; documents production requirements; enforces without Sentinel
- **Why not only rely on Sentinel**: Not all teams have Sentinel; local validation is faster feedback

### Why Feature Flags in scale_profile
- **Chosen**: enable_gateway and enable_memory as booleans in scale_profile
- **Why**: Keeps all environment config together; prevents separate feature flag variables; clear audit trail
- **Why not separate variables**: Fragments configuration; harder to reason about environment state



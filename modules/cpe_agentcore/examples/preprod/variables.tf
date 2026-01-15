# Variables inherited from root module - see ../../variables.tf for full definitions

variable "environment" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "aws_account_id" {
  type = string
}

variable "vpc_config" {
  type = object({
    vpc_id = string
    private_subnet_ids = map(object({
      subnet_id         = string
      availability_zone = string
      cidr_block        = string
    }))
    public_subnet_ids = optional(map(string), {})
    security_group_ids = object({
      agentcore_runtime  = string
      vpc_endpoints      = string
      nat_gateway_egress = string
    })
    route_table_ids = map(string)
  })
}

variable "scale_profile" {
  type = object({
    nat_mode                       = string
    vpc_endpoint_az_count          = number
    runtime_concurrency_limit      = number
    runtime_memory_mb              = number
    runtime_timeout_seconds        = number
    log_retention_days             = number
    metrics_resolution_seconds     = number
    alarm_evaluation_periods       = number
    tool_execution_timeout_seconds = number
    tool_max_concurrent_executions = number
    enable_gateway                 = bool
    enable_memory                  = bool
  })
}

variable "agents" {
  type = map(object({
    name                     = string
    description              = string
    runtime_version_digest   = string
    capability_bundles       = set(string)
    custom_policy_arns       = optional(set(string), [])
    memory_mb_override       = optional(number)
    timeout_seconds_override = optional(number)
    additional_tags          = optional(map(string), {})
  }))
}

variable "cross_account_access" {
  type = object({
    enabled                 = bool
    allowed_caller_accounts = set(string)
    allowed_caller_roles    = map(set(string))
    allowed_caller_vpc_ids  = optional(set(string), [])
  })
  default = {
    enabled                 = false
    allowed_caller_accounts = []
    allowed_caller_roles    = {}
    allowed_caller_vpc_ids  = []
  }
}

variable "observability_config" {
  type = object({
    splunk_hec_endpoint         = string
    splunk_hec_token_secret_arn = string
    alarm_sns_topic_arn         = string
    enable_xray_tracing         = bool
    dashboard_enabled           = bool
  })
}

variable "tags" {
  type    = map(string)
  default = {}
}



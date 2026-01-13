variable "environment" {
  description = "Environment identifier"
  type        = string
}

variable "name_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for gateway"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for gateway"
  type        = list(string)
}

variable "execution_role_arns" {
  description = "Map of agent key to execution role ARN"
  type        = map(string)
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
}


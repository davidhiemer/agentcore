# ==============================================================================
# NETWORK SUBMODULE OUTPUTS
# ==============================================================================

# ------------------------------------------------------------------------------
# SUBNET OUTPUTS
# ------------------------------------------------------------------------------

output "private_subnet_ids" {
  description = "Map of AZ to private subnet ID"
  value       = { for az, subnet in aws_subnet.private : az => subnet.id }
}

output "private_subnet_ids_list" {
  description = "List of private subnet IDs"
  value       = [for subnet in aws_subnet.private : subnet.id]
}

output "private_subnet_cidrs" {
  description = "Map of AZ to private subnet CIDR"
  value       = { for az, subnet in aws_subnet.private : az => subnet.cidr_block }
}

output "public_subnet_ids" {
  description = "Map of AZ to public subnet ID"
  value       = { for az, subnet in aws_subnet.public : az => subnet.id }
}

output "public_subnet_ids_list" {
  description = "List of public subnet IDs"
  value       = [for subnet in aws_subnet.public : subnet.id]
}

output "public_subnet_cidrs" {
  description = "Map of AZ to public subnet CIDR"
  value       = { for az, subnet in aws_subnet.public : az => subnet.cidr_block }
}

# ------------------------------------------------------------------------------
# ROUTE TABLE OUTPUTS
# ------------------------------------------------------------------------------

output "private_route_table_ids" {
  description = "Map of AZ to private route table ID"
  value       = { for az, rt in aws_route_table.private : az => rt.id }
}

output "public_route_table_id" {
  description = "Public route table ID"
  value       = aws_route_table.public.id
}

# ------------------------------------------------------------------------------
# SECURITY GROUP OUTPUTS
# ------------------------------------------------------------------------------

output "security_group_ids" {
  description = "Map of security group purpose to ID"
  value = {
    agentcore_runtime  = aws_security_group.agentcore_runtime.id
    vpc_endpoints      = aws_security_group.vpc_endpoints.id
    nat_gateway_egress = aws_security_group.nat_gateway_egress.id
  }
}

output "agentcore_runtime_security_group_id" {
  description = "Security group ID for AgentCore runtime"
  value       = aws_security_group.agentcore_runtime.id
}

output "vpc_endpoints_security_group_id" {
  description = "Security group ID for VPC endpoints"
  value       = aws_security_group.vpc_endpoints.id
}

# ------------------------------------------------------------------------------
# NAT GATEWAY OUTPUTS
# ------------------------------------------------------------------------------

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs"
  value       = [for nat in aws_nat_gateway.this : nat.id]
}

output "nat_gateway_public_ips" {
  description = "Map of AZ to NAT gateway public IP"
  value       = { for k, v in aws_nat_gateway.this : k => aws_eip.nat[k].public_ip }
}

# ------------------------------------------------------------------------------
# INTERNET GATEWAY OUTPUTS
# ------------------------------------------------------------------------------

output "internet_gateway_id" {
  description = "Internet Gateway ID"
  value       = local.internet_gateway_id
}

# ------------------------------------------------------------------------------
# VPC ENDPOINT OUTPUTS
# ------------------------------------------------------------------------------

output "vpc_endpoint_ids" {
  description = "Map of service name to VPC endpoint ID"
  value = merge(
    { for k, v in aws_vpc_endpoint.gateway : k => v.id },
    { for k, v in aws_vpc_endpoint.interface : k => v.id }
  )
}

output "vpc_endpoint_arns" {
  description = "Map of service name to VPC endpoint ARN"
  value = merge(
    { for k, v in aws_vpc_endpoint.gateway : k => v.arn },
    { for k, v in aws_vpc_endpoint.interface : k => v.arn }
  )
}

output "vpc_endpoint_dns_entries" {
  description = "Map of service name to VPC endpoint DNS entries"
  value = {
    for k, v in aws_vpc_endpoint.interface : k => v.dns_entry
  }
}

# ------------------------------------------------------------------------------
# PRIVATE HOSTED ZONE OUTPUTS
# ------------------------------------------------------------------------------

output "private_hosted_zone_id" {
  description = "Route 53 private hosted zone ID for AgentCore control plane"
  value       = aws_route53_zone.agentcore.zone_id
}

output "private_hosted_zone_name" {
  description = "Route 53 private hosted zone name for AgentCore"
  value       = aws_route53_zone.agentcore.name
}

output "runtime_private_hosted_zone_id" {
  description = "Route 53 private hosted zone ID for AgentCore runtime"
  value       = aws_route53_zone.agentcore_runtime.zone_id
}

output "runtime_private_hosted_zone_name" {
  description = "Route 53 private hosted zone name for AgentCore runtime"
  value       = aws_route53_zone.agentcore_runtime.name
}

# ------------------------------------------------------------------------------
# VPC FLOW LOGS OUTPUTS
# ------------------------------------------------------------------------------

output "vpc_flow_log_group_arn" {
  description = "CloudWatch log group ARN for VPC flow logs"
  value       = aws_cloudwatch_log_group.vpc_flow_logs.arn
}

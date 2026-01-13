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

output "nat_gateway_ids" {
  description = "List of NAT gateway IDs"
  value       = [for nat in aws_nat_gateway.this : nat.id]
}

output "nat_gateway_public_ips" {
  description = "Map of AZ to NAT gateway public IP"
  value       = { for k, v in aws_nat_gateway.this : k => aws_eip.nat[k].public_ip }
}

output "private_hosted_zone_id" {
  description = "Route 53 private hosted zone ID for AgentCore"
  value       = aws_route53_zone.agentcore.zone_id
}

output "private_hosted_zone_name" {
  description = "Route 53 private hosted zone name"
  value       = aws_route53_zone.agentcore.name
}


# ==============================================================================
# NETWORK SUBMODULE
# VPC endpoints, NAT gateways, and private DNS configuration
# For Amazon Bedrock AgentCore Platform
# ==============================================================================

# ------------------------------------------------------------------------------
# NAT GATEWAYS
# ------------------------------------------------------------------------------

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat" {
  for_each = toset(var.nat_gateway_azs)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })
}

# NAT Gateways (one per configured AZ)
resource "aws_nat_gateway" "this" {
  for_each = length(var.public_subnet_ids) > 0 ? toset(var.nat_gateway_azs) : toset([])

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = var.public_subnet_ids[each.key]

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  lifecycle {
    precondition {
      condition     = !(var.environment == "prod" && var.nat_mode != "per_az")
      error_message = "Production must use NAT per AZ for HA."
    }
  }
}

# Routes to NAT Gateway
resource "aws_route" "nat" {
  for_each = length(aws_nat_gateway.this) > 0 ? var.route_table_ids : {}

  route_table_id         = each.value
  destination_cidr_block = "0.0.0.0/0"

  # Route to NAT in same AZ (if per_az) or single NAT (if single mode)
  nat_gateway_id = var.nat_mode == "per_az" ? (
    aws_nat_gateway.this[each.key].id
  ) : (
    aws_nat_gateway.this[var.nat_gateway_azs[0]].id
  )
}

# ------------------------------------------------------------------------------
# GATEWAY VPC ENDPOINTS (S3, DynamoDB)
# ------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type = "Gateway"

  route_table_ids = values(var.route_table_ids)

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-${each.key}"
  })
}

# ------------------------------------------------------------------------------
# INTERFACE VPC ENDPOINTS
# AgentCore and AWS services
# ------------------------------------------------------------------------------

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # Deploy to configured number of AZs
  subnet_ids = var.vpc_endpoint_subnet_ids

  security_group_ids = [var.security_group_ids.vpc_endpoints]

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-vpce-${each.key}"
    Service = each.key
  })
}

# ------------------------------------------------------------------------------
# PRIVATE HOSTED ZONE FOR AGENTCORE
# Enables cross-account private access to AgentCore APIs
# ------------------------------------------------------------------------------

resource "aws_route53_zone" "agentcore" {
  name = "bedrock-agentcore.${var.aws_region}.amazonaws.com"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-phz-agentcore"
    Purpose = "AgentCore private DNS resolution"
  })

  lifecycle {
    ignore_changes = [vpc]
  }
}

# Additional private hosted zone for AgentCore runtime
resource "aws_route53_zone" "agentcore_runtime" {
  name = "bedrock-agentcore-runtime.${var.aws_region}.amazonaws.com"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-phz-agentcore-runtime"
    Purpose = "AgentCore runtime private DNS resolution"
  })

  lifecycle {
    ignore_changes = [vpc]
  }
}

# Alias record for AgentCore control plane
resource "aws_route53_record" "agentcore" {
  count = contains(var.interface_endpoints, "bedrock-agentcore") ? 1 : 0

  zone_id = aws_route53_zone.agentcore.zone_id
  name    = "bedrock-agentcore.${var.aws_region}.amazonaws.com"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.interface["bedrock-agentcore"].dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.interface["bedrock-agentcore"].dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = true
  }
}

# Alias record for AgentCore runtime
resource "aws_route53_record" "agentcore_runtime" {
  count = contains(var.interface_endpoints, "bedrock-agentcore-runtime") ? 1 : 0

  zone_id = aws_route53_zone.agentcore_runtime.zone_id
  name    = "bedrock-agentcore-runtime.${var.aws_region}.amazonaws.com"
  type    = "A"

  alias {
    name                   = aws_vpc_endpoint.interface["bedrock-agentcore-runtime"].dns_entry[0]["dns_name"]
    zone_id                = aws_vpc_endpoint.interface["bedrock-agentcore-runtime"].dns_entry[0]["hosted_zone_id"]
    evaluate_target_health = true
  }
}

# ------------------------------------------------------------------------------
# CROSS-ACCOUNT PHZ ASSOCIATIONS
# Allow caller accounts to resolve AgentCore endpoints privately
# ------------------------------------------------------------------------------

resource "aws_route53_vpc_association_authorization" "agentcore" {
  for_each = var.cross_account_access.enabled ? var.cross_account_access.allowed_caller_vpc_ids : toset([])

  zone_id = aws_route53_zone.agentcore.zone_id
  vpc_id  = each.value
}

resource "aws_route53_vpc_association_authorization" "agentcore_runtime" {
  for_each = var.cross_account_access.enabled ? var.cross_account_access.allowed_caller_vpc_ids : toset([])

  zone_id = aws_route53_zone.agentcore_runtime.zone_id
  vpc_id  = each.value
}

# ==============================================================================
# NETWORK SUBMODULE
# Creates all networking infrastructure within the provided VPC:
# - Private and Public Subnets
# - Route Tables
# - NAT Gateways
# - Internet Gateway (optional)
# - Security Groups
# - VPC Endpoints
# - Private Hosted Zones
# ==============================================================================

locals {
  az_count = length(var.availability_zones)

  # Calculate subnet CIDRs dynamically
  private_subnet_cidrs = {
    for idx, az in var.availability_zones :
    az => cidrsubnet(
      var.vpc_cidr,
      var.subnet_config.private_subnet_newbits,
      var.subnet_config.private_subnet_start_netnum + idx
    )
  }

  public_subnet_cidrs = {
    for idx, az in var.availability_zones :
    az => cidrsubnet(
      var.vpc_cidr,
      var.subnet_config.public_subnet_newbits,
      var.subnet_config.public_subnet_start_netnum + idx
    )
  }

  # NAT Gateway AZs based on mode
  nat_gateway_azs = var.nat_mode == "per_az" ? var.availability_zones : [var.availability_zones[0]]

  # VPC endpoint subnets (limited by vpc_endpoint_az_count)
  vpc_endpoint_azs = slice(var.availability_zones, 0, min(var.vpc_endpoint_az_count, local.az_count))
}

# ==============================================================================
# INTERNET GATEWAY
# ==============================================================================

# Look up existing IGW attached to VPC if not provided
data "aws_internet_gateway" "existing" {
  count = var.internet_gateway_id == null ? 1 : 0

  filter {
    name   = "attachment.vpc-id"
    values = [var.vpc_id]
  }
}

# Create IGW only if not provided AND none exists on VPC
resource "aws_internet_gateway" "this" {
  count = var.internet_gateway_id == null && length(data.aws_internet_gateway.existing) == 0 ? 1 : 0

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

locals {
  # Priority: provided ID > existing on VPC > newly created
  internet_gateway_id = coalesce(
    var.internet_gateway_id,
    try(data.aws_internet_gateway.existing[0].id, null),
    try(aws_internet_gateway.this[0].id, null)
  )
}

# ==============================================================================
# PUBLIC SUBNETS
# ==============================================================================

resource "aws_subnet" "public" {
  for_each = local.public_subnet_cidrs

  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                        = "${var.name_prefix}-public-${each.key}"
    Tier                        = "public"
    "kubernetes.io/role/elb"    = "1"
  })
}

# ==============================================================================
# PRIVATE SUBNETS
# ==============================================================================

resource "aws_subnet" "private" {
  for_each = local.private_subnet_cidrs

  vpc_id                  = var.vpc_id
  cidr_block              = each.value
  availability_zone       = each.key
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name                              = "${var.name_prefix}-private-${each.key}"
    Tier                              = "private"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# ==============================================================================
# PUBLIC ROUTE TABLE
# ==============================================================================

resource "aws_route_table" "public" {
  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
    Tier = "public"
  })
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = local.internet_gateway_id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ==============================================================================
# PRIVATE ROUTE TABLES (one per AZ for NAT per-AZ, or shared for single NAT)
# ==============================================================================

resource "aws_route_table" "private" {
  for_each = toset(var.availability_zones)

  vpc_id = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-private-rt-${each.key}"
    Tier = "private"
    AZ   = each.key
  })
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

# ==============================================================================
# NAT GATEWAYS
# ==============================================================================

resource "aws_eip" "nat" {
  for_each = toset(local.nat_gateway_azs)

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-eip-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  for_each = toset(local.nat_gateway_azs)

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-${each.key}"
  })

  depends_on = [aws_internet_gateway.this]
}

# Routes to NAT Gateway
resource "aws_route" "private_nat" {
  for_each = aws_route_table.private

  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"

  # Route to NAT in same AZ (if per_az) or single NAT (if single mode)
  nat_gateway_id = var.nat_mode == "per_az" ? (
    aws_nat_gateway.this[each.key].id
  ) : (
    aws_nat_gateway.this[local.nat_gateway_azs[0]].id
  )
}

# ==============================================================================
# SECURITY GROUPS
# ==============================================================================

# Security Group for AgentCore Runtime
resource "aws_security_group" "agentcore_runtime" {
  name        = "${var.name_prefix}-agentcore-runtime"
  description = "Security group for AgentCore runtime containers"
  vpc_id      = var.vpc_id

  # Ingress from VPC (for internal communication)
  ingress {
    description = "Allow traffic from VPC"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Egress to anywhere (for API calls, model invocation, etc.)
  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-agentcore-runtime-sg"
  })
}

# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.name_prefix}-vpc-endpoints"
  description = "Security group for VPC endpoints"
  vpc_id      = var.vpc_id

  # Allow HTTPS from VPC
  ingress {
    description = "HTTPS from VPC"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Allow from AgentCore runtime SG
  ingress {
    description     = "HTTPS from AgentCore runtime"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.agentcore_runtime.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-endpoints-sg"
  })
}

# Security Group for NAT Gateway traffic (optional, for monitoring)
resource "aws_security_group" "nat_gateway_egress" {
  name        = "${var.name_prefix}-nat-egress"
  description = "Security group for tracking NAT gateway egress"
  vpc_id      = var.vpc_id

  egress {
    description = "Allow all outbound via NAT"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-nat-egress-sg"
  })
}

# ==============================================================================
# GATEWAY VPC ENDPOINTS (S3, DynamoDB) - Free, use route tables
# ==============================================================================

resource "aws_vpc_endpoint" "gateway" {
  for_each = var.gateway_endpoints

  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    [aws_route_table.public.id],
    [for rt in aws_route_table.private : rt.id]
  )

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpce-${each.key}"
  })
}

# ==============================================================================
# INTERFACE VPC ENDPOINTS - AgentCore and AWS services
# ==============================================================================

resource "aws_vpc_endpoint" "interface" {
  for_each = var.interface_endpoints

  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true

  # Deploy to configured number of AZs
  subnet_ids = [for az in local.vpc_endpoint_azs : aws_subnet.private[az].id]

  security_group_ids = [aws_security_group.vpc_endpoints.id]

  tags = merge(var.tags, {
    Name    = "${var.name_prefix}-vpce-${each.key}"
    Service = each.key
  })
}

# ==============================================================================
# PRIVATE HOSTED ZONE FOR AGENTCORE
# Enables cross-account private access to AgentCore APIs
# ==============================================================================

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

# ==============================================================================
# CROSS-ACCOUNT PHZ ASSOCIATIONS
# Allow caller accounts to resolve AgentCore endpoints privately
# ==============================================================================

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

# ==============================================================================
# VPC FLOW LOGS (Optional - for network visibility)
# ==============================================================================

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.name_prefix}/flow-logs"
  retention_in_days = 30

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-flow-logs"
  })
}

resource "aws_iam_role" "vpc_flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "vpc_flow_logs" {
  name = "${var.name_prefix}-vpc-flow-logs-policy"
  role = aws_iam_role.vpc_flow_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogGroups",
        "logs:DescribeLogStreams"
      ]
      Effect   = "Allow"
      Resource = "*"
    }]
  })
}

resource "aws_flow_log" "main" {
  iam_role_arn    = aws_iam_role.vpc_flow_logs.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc-flow-log"
  })
}

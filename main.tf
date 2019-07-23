data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  max_az     = 6
  max_subnet = 32
  az_count   = length(data.aws_availability_zones.available.names) > local.max_az ? local.max_az : length(data.aws_availability_zones.available.names)
}

resource "aws_vpc" "main" {
  assign_generated_ipv6_cidr_block = var.assign_generated_ipv6_cidr_block
  cidr_block                       = var.cidr_block
  enable_dns_hostnames             = var.enable_dns_hostnames
  enable_dns_support               = var.enable_dns_support
  instance_tenancy                 = var.instance_tenancy
  tags                             = merge({
    "Name" = format("%s-VPC", var.name)
  },
  var.tags,
  )
}

resource "aws_subnet" "public" {
  count                           = local.az_count
  assign_ipv6_address_on_creation = var.assign_generated_ipv6_cidr_block
  availability_zone_id            = data.aws_availability_zones.available.zone_ids[count.index]
  cidr_block                      = cidrsubnet(var.cidr_block, ceil(log(local.max_subnet, 2)), count.index)
  ipv6_cidr_block                 = var.assign_generated_ipv6_cidr_block ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)  : null
  map_public_ip_on_launch         = true
  vpc_id                          = aws_vpc.main.id
  tags                            = merge(
  {
    "Name" = format("%s-%s-%s",
    var.name,
    "public",
    data.aws_availability_zones.available.names[count.index]
    )
    "AZ"   = data.aws_availability_zones.available.names[count.index],
    "Type" = "public"
  },
  var.tags,
  )
}

resource "aws_subnet" "private" {
  count                           = local.az_count
  assign_ipv6_address_on_creation = var.assign_generated_ipv6_cidr_block
  availability_zone_id            = data.aws_availability_zones.available.zone_ids[count.index]
  cidr_block                      = cidrsubnet(var.cidr_block, ceil(log(local.max_subnet, 2)), local.max_az + count.index)
  ipv6_cidr_block                 = var.assign_generated_ipv6_cidr_block ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, local.max_az + count.index)  : null
  vpc_id                          = aws_vpc.main.id
  tags                            = merge(
  {
    "Name" = format("%s-%s-%s",
    var.name,
    "private",
    data.aws_availability_zones.available.names[count.index]
    )
    "AZ"   = data.aws_availability_zones.available.names[count.index],
    "Type" = "private"
  },
  var.tags,
  )
}

resource "aws_subnet" "database" {
  count                           = local.az_count
  assign_ipv6_address_on_creation = var.assign_generated_ipv6_cidr_block
  availability_zone_id            = data.aws_availability_zones.available.zone_ids[count.index]
  cidr_block                      = cidrsubnet(var.cidr_block, ceil(log(local.max_subnet, 2)), local.max_az * 2 + count.index)
  ipv6_cidr_block                 = var.assign_generated_ipv6_cidr_block ? cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, local.max_az * 2 + count.index)  : null
  vpc_id                          = aws_vpc.main.id
  tags                            = merge(
  {
    "Name" = format("%s-%s-%s",
    var.name,
    "database",
    data.aws_availability_zones.available.names[count.index]
    )
    "AZ"   = data.aws_availability_zones.available.names[count.index],
    "Type" = "database"
  },
  var.tags,
  )
}

resource "aws_route_table" "public" {
  count  = length(aws_subnet.public)
  vpc_id = aws_vpc.main.id

  tags = merge(
  {
    "Name" = format("%s-public-%s",
    var.name,
    data.aws_availability_zones.available.names[count.index]
    )
    "Type" = "public",
    "AZ"   = data.aws_availability_zones.available.names[count.index]
  },
  var.tags,
  )
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public.*.id[count.index]
  route_table_id = aws_route_table.public.*.id[count.index]
  depends_on     = [
    aws_subnet.public,
    aws_route_table.public,
  ]
}

resource "aws_route_table" "private" {
  count  = length(aws_subnet.private)
  vpc_id = aws_vpc.main.id

  tags = merge(
  {
    "Name" = format("%s-private-%s",
    var.name,
    data.aws_availability_zones.available.names[count.index]
    )
    "Type" = "private",
    "AZ"   = data.aws_availability_zones.available.names[count.index]
  },
  var.tags,
  )
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private.*.id[count.index]
  route_table_id = aws_route_table.private.*.id[count.index]
  depends_on     = [
    aws_subnet.private,
    aws_route_table.private,
  ]
}

resource "aws_route_table" "database" {
  count  = length(aws_subnet.database)
  vpc_id = aws_vpc.main.id

  tags = merge(
  {
    "Name" = format("%s-database-%s",
    var.name,
    data.aws_availability_zones.available.names[count.index]
    )
    "Type" = "database",
    "AZ"   = data.aws_availability_zones.available.names[count.index]
  },
  var.tags,
  )
}

resource "aws_route_table_association" "database" {
  count          = length(aws_subnet.database)
  subnet_id      = aws_subnet.database.*.id[count.index]
  route_table_id = aws_route_table.database.*.id[count.index]
  depends_on     = [
    aws_subnet.database,
    aws_route_table.database,
  ]
}

resource "aws_internet_gateway" "gateway" {
  vpc_id = aws_vpc.main.id

  tags = merge({
    "Name" = format("%s", var.name)
  },
  var.tags,
  )
}

resource "aws_egress_only_internet_gateway" "egress_gateway" {
  vpc_id = aws_vpc.main.id
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? length(aws_subnet.public) : 0
  vpc   = true
  tags  = merge(
  {
    "Name" = format("%s-%s-%s",
    var.name,
    "nat-eip",
    data.aws_availability_zones.available.names[count.index]
    )
    "AZ"   = data.aws_availability_zones.available.names[count.index]
  },
  var.tags,
  )
}

resource "aws_nat_gateway" "nat_gateway" {
  count         = var.enable_nat_gateway ? length(aws_subnet.public) : 0
  allocation_id = aws_eip.nat.*.id[count.index]
  subnet_id     = aws_subnet.public.*.id[count.index]

  tags = merge(
  {
    "Name" = format("%s-%s-%s",
    var.name,
    "nat-gateway",
    data.aws_availability_zones.available.names[count.index]
    )
    "AZ"   = data.aws_availability_zones.available.names[count.index]
  },
  var.tags,
  )
}

resource "aws_route" "igw" {
  count                  = length(aws_route_table.public)
  route_table_id         = aws_route_table.public.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gateway.id
}

resource "aws_route" "igw_ipv6" {
  count                       = length(aws_route_table.public)
  route_table_id              = aws_route_table.public.*.id[count.index]
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = aws_internet_gateway.gateway.id
}

resource "aws_route" "private_igw_ipv6" {
  count                       = length(aws_route_table.private)
  route_table_id              = aws_route_table.private.*.id[count.index]
  destination_ipv6_cidr_block = "::/0"
  egress_only_gateway_id      = aws_egress_only_internet_gateway.egress_gateway.id
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.enable_nat_gateway ? length(aws_subnet.private) : 0
  route_table_id         = aws_route_table.private.*.id[count.index]
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway.*.id[count.index]
}

resource "aws_network_acl" "public" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.public.*.id

  tags = merge(
  {
    "Name" = format("%s-%s",
    var.name,
    "public"
    )
  },
  var.tags,
  )
}

resource "aws_network_acl" "private" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.private.*.id

  tags = merge(
  {
    "Name" = format("%s-%s",
    var.name,
    "private"
    )
  },
  var.tags,
  )
}

resource "aws_network_acl" "database" {
  vpc_id     = aws_vpc.main.id
  subnet_ids = aws_subnet.database.*.id

  tags = merge(
  {
    "Name" = format("%s-%s",
    var.name,
    "database"
    )
  },
  var.tags,
  )
}

resource "aws_network_acl_rule" "public_inbound" {
  count = length(var.public_inbound_acl_rules)

  network_acl_id = aws_network_acl.public.id

  egress          = false
  rule_number     = var.public_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.public_inbound_acl_rules[count.index]["rule_action"]
  from_port       = var.public_inbound_acl_rules[count.index]["from_port"]
  to_port         = var.public_inbound_acl_rules[count.index]["to_port"]
  protocol        = var.public_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.public_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.public_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "public_outbound" {
  count = length(var.public_outbound_acl_rules)

  network_acl_id = aws_network_acl.public.id

  egress          = true
  rule_number     = var.public_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.public_outbound_acl_rules[count.index]["rule_action"]
  from_port       = var.public_outbound_acl_rules[count.index]["from_port"]
  to_port         = var.public_outbound_acl_rules[count.index]["to_port"]
  protocol        = var.public_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.public_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.public_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "private_inbound" {
  count = length(var.private_inbound_acl_rules)

  network_acl_id = aws_network_acl.private.id

  egress          = false
  rule_number     = var.private_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_inbound_acl_rules[count.index]["rule_action"]
  from_port       = var.private_inbound_acl_rules[count.index]["from_port"]
  to_port         = var.private_inbound_acl_rules[count.index]["to_port"]
  protocol        = var.private_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "private_outbound" {
  count = length(var.private_outbound_acl_rules)

  network_acl_id = aws_network_acl.private.id

  egress          = true
  rule_number     = var.private_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.private_outbound_acl_rules[count.index]["rule_action"]
  from_port       = var.private_outbound_acl_rules[count.index]["from_port"]
  to_port         = var.private_outbound_acl_rules[count.index]["to_port"]
  protocol        = var.private_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.private_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.private_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "database_inbound" {
  count = length(var.database_inbound_acl_rules)

  network_acl_id = aws_network_acl.database.id

  egress          = false
  rule_number     = var.database_inbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.database_inbound_acl_rules[count.index]["rule_action"]
  from_port       = var.database_inbound_acl_rules[count.index]["from_port"]
  to_port         = var.database_inbound_acl_rules[count.index]["to_port"]
  protocol        = var.database_inbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.database_inbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.database_inbound_acl_rules[count.index], "ipv6_cidr_block", null)
}

resource "aws_network_acl_rule" "database_outbound" {
  count = length(var.database_outbound_acl_rules)

  network_acl_id = aws_network_acl.database.id

  egress          = true
  rule_number     = var.database_outbound_acl_rules[count.index]["rule_number"]
  rule_action     = var.database_outbound_acl_rules[count.index]["rule_action"]
  from_port       = var.database_outbound_acl_rules[count.index]["from_port"]
  to_port         = var.database_outbound_acl_rules[count.index]["to_port"]
  protocol        = var.database_outbound_acl_rules[count.index]["protocol"]
  cidr_block      = lookup(var.database_outbound_acl_rules[count.index], "cidr_block", null)
  ipv6_cidr_block = lookup(var.database_outbound_acl_rules[count.index], "ipv6_cidr_block", null)
}
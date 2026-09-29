resource "aws_vpc" "cloud_lab" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "aws-cloud-lab"
  }
}

resource "aws_subnet" "subnets" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.cloud_lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public_ip

  tags = {
    Name = each.value.name
  }
}

resource "aws_internet_gateway" "cloud_lab" {
  vpc_id = aws_vpc.cloud_lab.id

  tags = {
    Name = "aws-cloud-lab-igw"
  }
}

resource "aws_route_table" "route_tables" {
  for_each = local.route_tables

  vpc_id = aws_vpc.cloud_lab.id

  tags = {
    Name = each.value.name
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables["public"].id
}

resource "aws_route_table_association" "private_db" {
  for_each = local.db_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables["private_db"].id
}

resource "aws_route_table_association" "private_app" {
  for_each = local.app_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables[each.key].id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.route_tables["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cloud_lab.id
}

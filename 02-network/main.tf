data "aws_availability_zones" "available" {}

resource "aws_vpc" "my_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "my_vpc"
  }
}

resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my_igw"
  }
}

resource "aws_default_route_table" "route" {
  default_route_table_id = aws_vpc.my_vpc.default_route_table_id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "default route"
  }
}

resource "aws_subnet" "public" {
  count             = length(var.subnet_public)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_public[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_public_${count.index}"
  }
}

resource "aws_subnet" "private" {
  count             = length(var.subnet_private)
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = var.subnet_private[count.index]
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "subnet_private_${count.index}"
  }
}

resource "aws_eip" "nat" {
  count  = length(var.subnet_public)
  domain = "vpc"

  tags = {
    Name = "eip_nat_${count.index}"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  count         = length(var.subnet_public)
  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[count.index].id

  tags = {
    Name = "nat_gw_${count.index}"
  }
}

resource "aws_route_table" "route" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "custom_route"
  }
}

resource "aws_route_table" "route_nat" {
  count  = length(var.subnet_public)
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat_gw[count.index].id
  }

  tags = {
    Name = "default_route_nat_${count.index}"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(var.subnet_public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.route.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.subnet_private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.route_nat[count.index].id
}

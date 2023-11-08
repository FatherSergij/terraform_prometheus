data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "aws_vpc_my" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name = "vpc_${var.my_name}",
  }
}

resource "aws_internet_gateway" "aws_igw" {
  vpc_id = aws_vpc.aws_vpc_my.id
  tags = {
    Name = "igw_${var.my_name}"
  }
}

resource "aws_subnet" "aws_subnet_my" {
  vpc_id                  = aws_vpc.aws_vpc_my.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = var.subnet_cidr
  map_public_ip_on_launch = true
  tags = {
    Name = "subnet_${var.my_name}"
  }
}

resource "aws_route_table" "aws_route_table_my" {
  vpc_id = aws_vpc.aws_vpc_my.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_igw.id
  }
  tags = {
    Name = "route_table_${var.my_name}"
  }
}

resource "aws_route_table_association" "associate_subnet_route_table_my" {
  subnet_id      = aws_subnet.aws_subnet_my.id
  route_table_id = aws_route_table.aws_route_table_my.id
}
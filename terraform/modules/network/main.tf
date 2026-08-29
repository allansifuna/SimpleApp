# VPC
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-${var.environment}-igw"
  }
}

# Public subnet for ALB and NAT gateway
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zone
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, 0)
  map_public_ip_on_launch = true

  tags = {
    Name   = "${var.project_name}-${var.environment}-public-${var.availability_zone}"
    Public = "true"
  }
}

# Private subnet for EC2
resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.availability_zone
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, 1)
  map_public_ip_on_launch = false

  tags = {
    Name   = "${var.project_name}-${var.environment}-private-${var.availability_zone}"
    Public = "false"
  }
}

# Second public subnet, ALB needs 2 AZs
resource "aws_subnet" "public_secondary" {
  vpc_id                  = aws_vpc.this.id
  availability_zone       = var.secondary_availability_zone
  cidr_block              = cidrsubnet(var.vpc_cidr_block, 4, 2)
  map_public_ip_on_launch = true

  tags = {
    Name   = "${var.project_name}-${var.environment}-public-${var.secondary_availability_zone}"
    Public = "true"
  }
}

resource "aws_route_table_association" "public_secondary" {
  subnet_id      = aws_subnet.public_secondary.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# NAT gateway
resource "aws_eip" "nat" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat-eip"
  }
}

resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  depends_on    = [aws_internet_gateway.this]

  tags = {
    Name = "${var.project_name}-${var.environment}-nat"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

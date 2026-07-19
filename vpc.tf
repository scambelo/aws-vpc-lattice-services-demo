data "aws_availability_zones" "available" {
  state = "available"
}

# Both VPCs intentionally use the same CIDR to demonstrate that
# VPC Lattice resolves CIDR overlap at Layer 7.
locals {
  cidr_a = "10.0.0.0/24"
  cidr_b = "10.0.0.0/24"
  azs    = slice(data.aws_availability_zones.available.names, 0, 2)
}

# --- VPC A (consumer) ---
resource "aws_vpc" "vpc_a" {
  cidr_block           = local.cidr_a
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-a-consumer" }
}

resource "aws_subnet" "vpc_a" {
  count             = 2
  vpc_id            = aws_vpc.vpc_a.id
  cidr_block        = cidrsubnet(local.cidr_a, 1, count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "vpc-a-${local.azs[count.index]}" }
}

# --- VPC B (provider) ---
resource "aws_vpc" "vpc_b" {
  cidr_block           = local.cidr_b
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "vpc-b-provider" }
}

resource "aws_subnet" "vpc_b" {
  count             = 2
  vpc_id            = aws_vpc.vpc_b.id
  cidr_block        = cidrsubnet(local.cidr_b, 1, count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "vpc-b-${local.azs[count.index]}" }
}

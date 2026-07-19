# SSM VPC endpoints for Session Manager access (no IGW needed)

resource "aws_security_group" "ssm" {
  for_each = {
    a = { vpc_id = aws_vpc.vpc_a.id, cidr = local.cidr_a }
    b = { vpc_id = aws_vpc.vpc_b.id, cidr = local.cidr_b }
  }

  name        = "ssm-endpoints-${each.key}"
  description = "Allow HTTPS for SSM endpoints"
  vpc_id      = each.value.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [each.value.cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "ssm-endpoints-${each.key}" }
}

locals {
  ssm_services = ["ssm", "ssmmessages", "ec2messages"]
  vpc_map = {
    a = { vpc_id = aws_vpc.vpc_a.id, subnet_ids = [aws_subnet.vpc_a[0].id], sg_id = aws_security_group.ssm["a"].id }
    b = { vpc_id = aws_vpc.vpc_b.id, subnet_ids = [aws_subnet.vpc_b[0].id], sg_id = aws_security_group.ssm["b"].id }
  }
  ssm_endpoints = flatten([
    for vpc_key, vpc in local.vpc_map : [
      for svc in local.ssm_services : {
        key       = "${vpc_key}-${svc}"
        vpc_id    = vpc.vpc_id
        svc       = svc
        sn_ids    = vpc.subnet_ids
        sg_id     = vpc.sg_id
      }
    ]
  ])
}

resource "aws_vpc_endpoint" "ssm" {
  for_each = { for e in local.ssm_endpoints : e.key => e }

  vpc_id              = each.value.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.${each.value.svc}"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = each.value.sn_ids
  security_group_ids  = [each.value.sg_id]
  private_dns_enabled = true

  tags = { Name = "ssm-${each.key}" }
}

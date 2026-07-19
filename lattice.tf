# =============================================================================
# VPC Lattice — Services model demo
#
# Service Network: shared connectivity plane
# VPC Association: connects VPC A (consumer) to the Service Network
# Service: publishes Instance B (provider) over HTTP
# Target Group: IP target pointing to Instance B
# Auth policy: AWS_IAM on Service Network — requires authenticated callers
# =============================================================================

# --- Service Network ---
resource "aws_vpclattice_service_network" "this" {
  name      = "demo-service-network"
  auth_type = "AWS_IAM"
  tags      = { Name = "demo-service-network" }
}

# Auth policy on the Service Network:
# Only authenticated principals from this account are allowed.
# Unsigned (anonymous) requests are rejected by the aws:PrincipalType condition.
data "aws_iam_policy_document" "service_network_auth" {
  statement {
    sid    = "AllowAuthenticatedAccountPrincipals"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["vpc-lattice-svcs:Invoke"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "aws:PrincipalType"
      values   = ["Anonymous"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:PrincipalAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_vpclattice_auth_policy" "service_network" {
  resource_identifier = aws_vpclattice_service_network.this.arn
  policy              = data.aws_iam_policy_document.service_network_auth.json
}

# --- VPC Association: connect VPC A (consumer) to the Service Network ---
resource "aws_security_group" "vpc_association" {
  name        = "vpc-lattice-association"
  description = "Allow HTTPS to VPC Lattice data plane from VPC A"
  vpc_id      = aws_vpc.vpc_a.id

  egress {
    description = "Allow HTTP to VPC Lattice data plane"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "vpc-lattice-association" }
}

resource "aws_vpclattice_service_network_vpc_association" "vpc_a" {
  vpc_identifier             = aws_vpc.vpc_a.id
  service_network_identifier = aws_vpclattice_service_network.this.id
  security_group_ids         = [aws_security_group.vpc_association.id]
  tags                       = { Name = "assoc-vpc-a" }
}

# --- Target Group: Instance B by IP ---
resource "aws_vpclattice_target_group" "service_b" {
  name = "tg-service-b"
  type = "IP"

  config {
    vpc_identifier = aws_vpc.vpc_b.id
    port           = 80
    protocol       = "HTTP"
    ip_address_type = "IPV4"

    health_check {
      enabled                      = true
      protocol                     = "HTTP"
      path                         = "/"
      healthy_threshold_count      = 2
      unhealthy_threshold_count    = 2
      health_check_interval_seconds = 30
    }
  }

  tags = { Name = "tg-service-b" }
}

resource "aws_vpclattice_target_group_attachment" "service_b" {
  target_group_identifier = aws_vpclattice_target_group.service_b.id

  target {
    id   = aws_instance.b.private_ip
    port = 80
  }
}

# --- VPC Lattice Service ---
resource "aws_vpclattice_service" "service_b" {
  name      = "service-b"
  auth_type = "AWS_IAM"
  tags      = { Name = "service-b" }
}

# Fine-grained auth policy on the Service:
# Only Instance A's IAM role can invoke Service B.
data "aws_iam_policy_document" "service_b_auth" {
  statement {
    sid    = "AllowInstanceARole"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.instance_a.arn]
    }
    actions   = ["vpc-lattice-svcs:Invoke"]
    resources = [aws_vpclattice_service.service_b.arn]
  }
}

resource "aws_vpclattice_auth_policy" "service_b" {
  resource_identifier = aws_vpclattice_service.service_b.arn
  policy              = data.aws_iam_policy_document.service_b_auth.json
}

# --- Listener: HTTP on port 80 ---
resource "aws_vpclattice_listener" "service_b" {
  name               = "http"
  service_identifier = aws_vpclattice_service.service_b.id
  protocol           = "HTTP"
  port               = 80

  default_action {
    forward {
      target_groups {
        target_group_identifier = aws_vpclattice_target_group.service_b.id
        weight                  = 100
      }
    }
  }

  tags = { Name = "service-b-http" }
}

# --- Associate Service with Service Network ---
resource "aws_vpclattice_service_network_service_association" "service_b" {
  service_identifier         = aws_vpclattice_service.service_b.id
  service_network_identifier = aws_vpclattice_service_network.this.id
  tags                       = { Name = "assoc-service-b" }
}

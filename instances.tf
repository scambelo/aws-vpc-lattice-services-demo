data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# --- IAM role for EC2 instances ---
data "aws_iam_policy_document" "ec2_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# Instance A role — needs vpc-lattice-svcs:Invoke to call the service with SigV4A
data "aws_iam_policy_document" "instance_a_policy" {
  statement {
    sid       = "AllowSSM"
    actions   = ["ssm:*", "ssmmessages:*", "ec2messages:*"]
    resources = ["*"]
  }
  statement {
    sid       = "AllowVPCLatticeInvoke"
    actions   = ["vpc-lattice-svcs:Invoke"]
    resources = ["arn:${data.aws_partition.current.partition}:vpc-lattice:${var.aws_region}:${data.aws_caller_identity.current.account_id}:service/*"]
  }
}

resource "aws_iam_role" "instance_a" {
  name               = "vpc-lattice-demo-instance-a"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "vpc-lattice-demo-instance-a" }
}

resource "aws_iam_role_policy" "instance_a" {
  name   = "vpc-lattice-demo-instance-a"
  role   = aws_iam_role.instance_a.name
  policy = data.aws_iam_policy_document.instance_a_policy.json
}

resource "aws_iam_instance_profile" "instance_a" {
  name = "vpc-lattice-demo-instance-a"
  role = aws_iam_role.instance_a.name
}

# Instance B role — SSM only
resource "aws_iam_role" "instance_b" {
  name               = "vpc-lattice-demo-instance-b"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume.json
  tags               = { Name = "vpc-lattice-demo-instance-b" }
}

resource "aws_iam_role_policy_attachment" "instance_b_ssm" {
  role       = aws_iam_role.instance_b.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance_b" {
  name = "vpc-lattice-demo-instance-b"
  role = aws_iam_role.instance_b.name
}

# --- Security groups for instances ---
resource "aws_security_group" "instance_a" {
  name        = "instance-a"
  description = "Instance A - allow HTTPS outbound (VPC Lattice), SSM"
  vpc_id      = aws_vpc.vpc_a.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "instance-a" }
}

resource "aws_security_group" "instance_b" {
  name        = "instance-b"
  description = "Instance B - allow HTTP from VPC Lattice link-local"
  vpc_id      = aws_vpc.vpc_b.id

  ingress {
    description = "HTTP from VPC Lattice data plane"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["169.254.171.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "instance-b" }
}

# --- Amazon Linux 2023 AMI ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# --- Instance A (consumer, VPC A) ---
resource "aws_instance" "a" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.vpc_a[0].id
  iam_instance_profile = aws_iam_instance_profile.instance_a.name
  vpc_security_group_ids = [aws_security_group.instance_a.id]

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3 python3-pip
    pip3 install botocore awscrt requests
  EOF

  tags = { Name = "instance-a-consumer" }
}

# --- Instance B (provider, VPC B) ---
resource "aws_instance" "b" {
  ami                  = data.aws_ami.al2023.id
  instance_type        = "t3.micro"
  subnet_id            = aws_subnet.vpc_b[0].id
  iam_instance_profile = aws_iam_instance_profile.instance_b.name
  vpc_security_group_ids = [aws_security_group.instance_b.id]

  user_data = <<-EOF
    #!/bin/bash
    IP=$(hostname -I | tr -d ' ')
    mkdir -p /var/www
    echo "Hello from Service B ($IP)" > /var/www/index.html
    cd /var/www && nohup python3 -m http.server 80 > /dev/null 2>&1 &
  EOF

  tags = { Name = "instance-b-provider" }
}

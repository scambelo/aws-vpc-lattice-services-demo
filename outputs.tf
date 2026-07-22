output "instance_a_id" {
  description = "Instance A (consumer) — connect via SSM Session Manager"
  value       = aws_instance.a.id
}

output "instance_b_id" {
  description = "Instance B (provider) — connect via SSM Session Manager"
  value       = aws_instance.b.id
}

output "service_b_domain" {
  description = "VPC Lattice auto-generated domain for Service B — use this to call the service from Instance A"
  value       = aws_vpclattice_service.service_b.dns_entry[0].domain_name
}

output "service_network_arn" {
  description = "Service Network ARN"
  value       = aws_vpclattice_service_network.this.arn
}

output "instance_a_role_arn" {
  description = "IAM role ARN of Instance A — referenced in the Service B auth policy"
  value       = aws_iam_role.instance_a.arn
}

output "note" {
  description = "Verification commands"
  value       = <<-EOT
    # 1. Connect to Instance A via SSM:
    aws ssm start-session --target ${aws_instance.a.id} --region ${var.aws_region}

    # 2. Inside Instance A — call Service B without signing (expect 403):
    curl http://${aws_vpclattice_service.service_b.dns_entry[0].domain_name}

    # 3. Inside Instance A — get credentials from instance metadata:
    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    CREDS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/iam/security-credentials/vpc-lattice-demo-instance-a)
    export AWS_ACCESS_KEY_ID=$(echo $CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKeyId'])")
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['SecretAccessKey'])")
    export AWS_SESSION_TOKEN=$(echo $CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['Token'])")

    # 4. Inside Instance A — call Service B with SigV4 signing via curl (expect 200):
    curl --aws-sigv4 "aws:amz:${var.aws_region}:vpc-lattice-svcs" \
         --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
         -H "x-amz-security-token: $AWS_SESSION_TOKEN" \
         -H "x-amz-content-sha256: UNSIGNED-PAYLOAD" \
         http://${aws_vpclattice_service.service_b.dns_entry[0].domain_name}
  EOT
}

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
    aws ssm start-session --target ${aws_instance.a.id} --region ${var.aws_region} --profile ${var.aws_profile}

    # 2. Call Service B without signing (expect 403):
    curl http://${aws_vpclattice_service.service_b.dns_entry[0].domain_name}

    # 3. Call Service B with SigV4A signing (expect 200):
    python3 /tmp/client.py ${aws_vpclattice_service.service_b.dns_entry[0].domain_name}
  EOT
}

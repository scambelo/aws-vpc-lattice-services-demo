variable "aws_region" {
  description = "AWS region to deploy the demo"
  type        = string
  default     = "eu-west-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use"
  type        = string
  default     = "sandbox"
}

variable "custom_domain" {
  description = "Custom domain for the VPC Lattice service (e.g. service-b.internal.example.com). Must match the ACM certificate."
  type        = string
  default     = "service-b.internal.example.com"
}

variable "hosted_zone_name" {
  description = "Route 53 private hosted zone name (e.g. internal.example.com)"
  type        = string
  default     = "internal.example.com"
}

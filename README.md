# AWS VPC Lattice Services Demo

Terraform demo for the blog post **[Amazon VPC Lattice: Service-to-Service Connectivity at Layer 7](https://cambelo.com/posts/vpc-lattice-service-to-service-layer7/)**.

Demonstrates service-to-service connectivity using **Amazon VPC Lattice Services** across two VPCs with overlapping CIDRs, secured with IAM auth policies and SigV4 request signing.

## Architecture

- **VPC A** (`10.0.0.0/24`) — consumer. EC2 instance (Instance A) that calls Service B.
- **VPC B** (`10.0.0.0/24`) — provider. EC2 instance (Instance B) running a Python HTTP server, exposed through VPC Lattice.
- **Service Network** with `AWS_IAM` auth type.
- **VPC Lattice Service** with HTTP listener and IP target group.
- **Two-layer auth policy**: service network guardrail (account-wide) + service policy (Instance A role only).
- **SSM VPC Endpoints** in both VPCs — no internet gateway needed.

Both VPCs intentionally use the same CIDR (`10.0.0.0/24`) to demonstrate that VPC Lattice resolves the overlap transparently at Layer 7.

## Prerequisites

- Terraform >= 1.5
- AWS CLI configured with credentials for your target account
- AWS account with permissions to create VPCs, EC2 instances, VPC Lattice resources, and IAM roles

## Usage

```shell
git clone https://github.com/scambelo/aws-vpc-lattice-services-demo.git
cd aws-vpc-lattice-services-demo

terraform init
terraform apply
```

To deploy in a different region:

```shell
terraform apply -var="aws_region=us-east-1"
```

Deployment takes 3-5 minutes. SSM VPC Endpoints are the slowest resource to provision.

Once complete, run the following to get the exact verification commands for your deployment — with the correct resource IDs and region already substituted:

```shell
terraform output note
```

## Verification

The output of `terraform output note` contains all commands ready to run. The steps below show what to expect at each stage.

### 1. Connect to Instance A via SSM

```shell
aws ssm start-session --target <instance_a_id> --region <aws_region>
```

### 2. Unsigned request — expect 403

```shell
curl http://<service_b_domain>

# AccessDeniedException: User: anonymous is not authorized to perform: vpc-lattice-svcs:Invoke
```

An unsigned request has no identity — it is treated as `anonymous` and rejected by the service network auth policy.

### 3. Signed request — expect 200

Retrieve credentials from the EC2 instance metadata and sign the request using curl's built-in `--aws-sigv4` flag. The signing region must match the region where you deployed:

```shell
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

CREDS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
  http://169.254.169.254/latest/meta-data/iam/security-credentials/<instance_a_role_name>)

export AWS_ACCESS_KEY_ID=$(echo $CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['AccessKeyId'])")
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['SecretAccessKey'])")
export AWS_SESSION_TOKEN=$(echo $CREDS | python3 -c "import sys,json; print(json.load(sys.stdin)['Token'])")

curl --aws-sigv4 "aws:amz:<aws_region>:vpc-lattice-svcs" \
     --user "$AWS_ACCESS_KEY_ID:$AWS_SECRET_ACCESS_KEY" \
     -H "x-amz-security-token: $AWS_SESSION_TOKEN" \
     -H "x-amz-content-sha256: UNSIGNED-PAYLOAD" \
     http://<service_b_domain>

# Hello from Service B (10.0.0.x)
```

> [!NOTE]
> Use `terraform output note` to get these commands with the correct values already filled in — `instance ID`, `role name`, `domain`, and `region`.

## Requirements

| Name | Version |
| ---- | ------- |
| [terraform](#requirement\_terraform) | >= 1.5 |
| [aws](#requirement\_aws) | >= 5.80 |

## Providers

| Name | Version |
| ---- | ------- |
| [aws](#provider\_aws) | >= 5.80 |

## Modules

No modules.

## Resources

| Name | Type |
| ---- | ---- |
| [aws_iam_instance_profile.instance_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_instance_profile.instance_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.instance_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.instance_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.instance_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.instance_b_ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_instance.a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_instance.b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance) | resource |
| [aws_security_group.instance_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.instance_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_association](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_subnet.vpc_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.vpc_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vpc_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc.vpc_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.vpc_association_http](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [aws_vpclattice_auth_policy.service_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_auth_policy) | resource |
| [aws_vpclattice_auth_policy.service_network](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_auth_policy) | resource |
| [aws_vpclattice_listener.service_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_listener) | resource |
| [aws_vpclattice_service.service_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service) | resource |
| [aws_vpclattice_service_network.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service_network) | resource |
| [aws_vpclattice_service_network_service_association.service_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service_network_service_association) | resource |
| [aws_vpclattice_service_network_vpc_association.vpc_a](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_service_network_vpc_association) | resource |
| [aws_vpclattice_target_group.service_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_target_group) | resource |
| [aws_vpclattice_target_group_attachment.service_b](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpclattice_target_group_attachment) | resource |
| [aws_ami.al2023](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ami) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.ec2_assume](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.instance_a_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service_b_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.service_network_auth](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default |
| ---- | ----------- | ---- | ------- |
| [aws\_profile](#input\_aws\_profile) | AWS CLI profile to use | `string` | `"sandbox"` |
| [aws\_region](#input\_aws\_region) | AWS region to deploy the demo | `string` | `"eu-west-1"` |
| [custom\_domain](#input\_custom\_domain) | Custom domain for the VPC Lattice service (e.g. service-b.internal.example.com). Must match the ACM certificate. | `string` | `"service-b.internal.example.com"` |
| [hosted\_zone\_name](#input\_hosted\_zone\_name) | Route 53 private hosted zone name (e.g. internal.example.com) | `string` | `"internal.example.com"` |

## Outputs

| Name | Description |
| ---- | ----------- |
| [instance\_a\_id](#output\_instance\_a\_id) | Instance A (consumer) — connect via SSM Session Manager |
| [instance\_a\_role\_arn](#output\_instance\_a\_role\_arn) | IAM role ARN of Instance A — referenced in the Service B auth policy |
| [instance\_b\_id](#output\_instance\_b\_id) | Instance B (provider) — connect via SSM Session Manager |
| [note](#output\_note) | Verification commands |
| [service\_b\_domain](#output\_service\_b\_domain) | VPC Lattice auto-generated domain for Service B — use this to call the service from Instance A |
| [service\_network\_arn](#output\_service\_network\_arn) | Service Network ARN |

## License

MIT

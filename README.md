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
git clone https://codeberg.org/scambelo/aws-vpc-lattice-services-demo.git
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

## Variables

| Variable | Description | Default |
|---|---|---|
| `aws_region` | AWS region to deploy | `eu-west-1` |

## Cleanup

```shell
terraform destroy
```

## Cost warning

> [!WARNING]
> This demo creates resources that incur AWS costs while deployed:
> - 6 SSM VPC Interface Endpoints (~$0.01/hour each)
> - VPC Lattice data processing charges
> - 2 EC2 t3.micro instances
>
> Always run `terraform destroy` when you are done.

## License

MIT

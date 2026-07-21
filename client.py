#!/usr/bin/env python3
"""
client.py — VPC Lattice SigV4A signing demo

Sends a GET request to a VPC Lattice service signed with SigV4A.
Credentials are resolved automatically from the EC2 instance profile.

Usage:
    python3 client.py <service-domain>

Example:
    python3 client.py service-b-0cf3ddabcbdecccdd.7d67968.vpc-lattice-svcs.eu-west-1.on.aws
"""

import sys
import requests
import botocore.session
from botocore import crt
from botocore.awsrequest import AWSRequest


def signed_get(url: str) -> requests.Response:
    """GET a VPC Lattice service URL with a SigV4A-signed request."""

    headers = {
        # VPC Lattice does not support payload signing.
        # This header is required — without it the signer will attempt
        # to hash the (empty) body and VPC Lattice will reject the request.
        "x-amz-content-sha256": "UNSIGNED-PAYLOAD",
    }

    aws_request = AWSRequest(method="GET", url=url, headers=headers)
    aws_request.context["payload_signing_enabled"] = False

    # SigV4A with region='*' — the signature is valid from any AWS region.
    # This is what makes it work both locally and cross-region without
    # changing any code. The signing service name for VPC Lattice is
    # 'vpc-lattice-svcs'.
    session = botocore.session.Session()
    credentials = session.get_credentials()

    signer = crt.auth.CrtSigV4AsymAuth(credentials, "vpc-lattice-svcs", "*")
    signer.add_auth(aws_request)

    prepped = aws_request.prepare()
    return requests.get(prepped.url, headers=dict(prepped.headers))


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <service-domain>")
        sys.exit(1)

    domain = sys.argv[1].strip()
    url = f"http://{domain}"

    print(f"Calling {url} with SigV4A signing...")
    response = signed_get(url)

    print(f"Status: {response.status_code}")
    print(f"Body:   {response.text.strip()}")

    if response.status_code == 200:
        print("\n✓ Request succeeded — SigV4A signing works correctly.")
    else:
        print("\n✗ Unexpected response. Check the auth policy and IAM role.")
        sys.exit(1)


if __name__ == "__main__":
    main()

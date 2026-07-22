#!/bin/bash
set -e

# Install pip and Python dependencies for SigV4A signing.
# Versions pinned to ensure wheel availability on AL2023/Python 3.11.
dnf install -y python3-pip
pip3 install \
  "botocore==1.38.0" \
  "awscrt==0.36.0" \
  "requests==2.32.3"

# Deploy the SigV4A client script.
cat > /home/ec2-user/client.py << 'PYEOF'
${client_py}
PYEOF

chown ec2-user:ec2-user /home/ec2-user/client.py
chmod +x /home/ec2-user/client.py

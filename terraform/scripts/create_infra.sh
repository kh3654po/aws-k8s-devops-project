#!/usr/bin/env bash
set -euo pipefail

MY_IP=$(curl -s https://checkip.amazonaws.com)

terraform fmt
terraform validate
terraform plan -out=tfplan \
  -var="my_ip_cidr=${MY_IP}/32"
terraform apply tfplan
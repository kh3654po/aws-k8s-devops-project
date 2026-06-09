#!/usr/bin/env bash
set -euo pipefail

MY_IP=$(curl -s https://checkip.amazonaws.com)

terraform plan -destroy -out=tfdestroyplan -var="my_ip_cidr=${MY_IP}/32"
terraform apply tfdestroyplan
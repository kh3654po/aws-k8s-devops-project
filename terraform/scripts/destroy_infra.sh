#!/usr/bin/env bash

set -euo pipefail

# ============================================================
# Path configuration
# ============================================================

# 현재 스크립트 위치:
# <PROJECT_ROOT>/terraform/scripts/destroy_infra.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Terraform 파일이 있는 디렉토리:
# <PROJECT_ROOT>/terraform
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 프로젝트 Root:
# <PROJECT_ROOT>
PROJECT_ROOT="$(cd "${TERRAFORM_DIR}/.." && pwd)"

# Ansible 디렉토리:
# <PROJECT_ROOT>/ansible
ANSIBLE_DIR="${PROJECT_ROOT}/ansible"

# Terraform Destroy Plan
PLAN_FILE="${TERRAFORM_DIR}/destroy.tfplan"

# Ansible Inventory
INVENTORY_FILE="${ANSIBLE_DIR}/inventory.ini"

# Kubernetes cloud resource cleanup playbook
CLEANUP_PLAYBOOK="${ANSIBLE_DIR}/cleanup-cloud-resources.yml"

# true이면 Terraform destroy 사용자 확인 생략
AUTO_APPROVE="${AUTO_APPROVE:-false}"

# ============================================================
# Cleanup
# ============================================================

cleanup() {
  rm -f "${PLAN_FILE}"
}

trap cleanup EXIT

# ============================================================
# Required commands
# ============================================================

for required_command in terraform curl ansible-playbook; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Error: ${required_command} command was not found."
    exit 1
  fi
done

# ============================================================
# Directory validation
# ============================================================

if [[ ! -d "${TERRAFORM_DIR}" ]]; then
  echo "Error: Terraform directory was not found."
  echo "Path: ${TERRAFORM_DIR}"
  exit 1
fi

if [[ ! -d "${ANSIBLE_DIR}" ]]; then
  echo "Error: Ansible directory was not found."
  echo "Path: ${ANSIBLE_DIR}"
  exit 1
fi

if [[ ! -f "${CLEANUP_PLAYBOOK}" ]]; then
  echo "Error: Kubernetes cloud cleanup playbook was not found."
  echo "Path: ${CLEANUP_PLAYBOOK}"
  exit 1
fi

# ============================================================
# Start
# ============================================================

echo "========================================"
echo "AWS Kubernetes Infrastructure Destruction"
echo "========================================"
echo
echo "Terraform directory : ${TERRAFORM_DIR}"
echo "Ansible directory   : ${ANSIBLE_DIR}"
echo "Project root        : ${PROJECT_ROOT}"
echo

# ============================================================
# 1. Detect current public IP
# ============================================================

echo "[1/8] Detecting current public IP..."

MY_IP="$(
  curl -fsS https://checkip.amazonaws.com |
    xargs
)"

if [[ -z "${MY_IP}" ]]; then
  echo "Error: Failed to detect the current public IP."
  exit 1
fi

MY_IP_CIDR="${MY_IP}/32"

echo "Current public IP: ${MY_IP_CIDR}"
echo

# ============================================================
# 2. Terraform init
# ============================================================

echo "[2/8] Initializing Terraform..."

terraform -chdir="${TERRAFORM_DIR}" init

echo

# ============================================================
# 3. Terraform validate
# ============================================================

echo "[3/8] Validating Terraform configuration..."

terraform -chdir="${TERRAFORM_DIR}" validate

echo

# ============================================================
# 4. Kubernetes-managed AWS resource cleanup
# ============================================================

echo "[4/8] Cleaning Kubernetes-managed AWS resources..."

if [[ -f "${INVENTORY_FILE}" ]]; then
  echo "Using Ansible inventory:"
  echo "${INVENTORY_FILE}"
  echo

  (
    cd "${ANSIBLE_DIR}"

    ansible-playbook \
      -i "${INVENTORY_FILE}" \
      cleanup-cloud-resources.yml
  )

  echo
  echo "Kubernetes-managed AWS resource cleanup completed."
else
  echo "WARNING: Ansible inventory was not found."
  echo "Path: ${INVENTORY_FILE}"
  echo
  echo "Unable to verify Kubernetes-managed AWS resources."
  echo "Terraform destroy has been blocked for safety."
  exit 1
fi

echo

# ============================================================
# 5. Terraform state
# ============================================================

echo "[5/8] Checking Terraform state..."

STATE_RESOURCES="$(
  terraform -chdir="${TERRAFORM_DIR}" state list 2>/dev/null || true
)"

if [[ -z "${STATE_RESOURCES}" ]]; then
  echo "No Terraform-managed resources were found."
  echo

  if [[ -f "${INVENTORY_FILE}" ]]; then
    rm -f "${INVENTORY_FILE}"

    echo "Removed stale Ansible inventory:"
    echo "${INVENTORY_FILE}"
    echo
  fi

  exit 0
fi

echo "Terraform-managed resources:"
echo "${STATE_RESOURCES}"
echo

# ============================================================
# 6. Create destroy plan
# ============================================================

echo "[6/8] Creating Terraform destroy plan..."

terraform -chdir="${TERRAFORM_DIR}" plan \
  -destroy \
  -out="${PLAN_FILE}" \
  -var="my_ip_cidr=${MY_IP_CIDR}"

echo

# ============================================================
# 7. Confirmation
# ============================================================

echo "[7/8] Confirming infrastructure destruction..."

if [[ "${AUTO_APPROVE}" != "true" ]]; then
  echo
  echo "WARNING:"
  echo "All Terraform-managed infrastructure will be destroyed."
  echo
  read -r -p "Type 'destroy' to continue: " CONFIRMATION

  if [[ "${CONFIRMATION}" != "destroy" ]]; then
    echo
    echo "Infrastructure destruction was cancelled."
    exit 0
  fi
else
  echo "AUTO_APPROVE=true"
  echo "Skipping interactive confirmation."
fi

echo

# ============================================================
# 8. Apply destroy plan
# ============================================================

echo "[8/8] Destroying Terraform infrastructure..."

terraform -chdir="${TERRAFORM_DIR}" apply \
  "${PLAN_FILE}"

echo

# ============================================================
# Remove inventory only after Terraform destroy succeeds
# ============================================================

if [[ -f "${INVENTORY_FILE}" ]]; then
  rm -f "${INVENTORY_FILE}"

  echo "Removed Ansible inventory:"
  echo "${INVENTORY_FILE}"
  echo
fi

echo "========================================"
echo "Infrastructure destruction completed"
echo "========================================"
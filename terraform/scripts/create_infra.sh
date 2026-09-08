#!/usr/bin/env bash

set -euo pipefail

# 현재 스크립트 위치:
# <PROJECT_ROOT>/terraform/scripts/create_infra.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Terraform 파일이 있는 디렉토리
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 프로젝트 root 디렉토리
PROJECT_ROOT="$(cd "${TERRAFORM_DIR}/.." && pwd)"

# Inventory 생성 스크립트
INVENTORY_SCRIPT="${PROJECT_ROOT}/scripts/generate_inventory.sh"

# Terraform plan 파일 이름
PLAN_FILE="tfplan"

# 필수 명령어 확인
for required_command in terraform curl; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Error: ${required_command} command was not found."
    exit 1
  fi
done

# Inventory 생성 스크립트 확인
if [[ ! -f "${INVENTORY_SCRIPT}" ]]; then
  echo "Error: Inventory generation script was not found."
  echo "Path: ${INVENTORY_SCRIPT}"
  exit 1
fi

if [[ ! -x "${INVENTORY_SCRIPT}" ]]; then
  echo "Error: Inventory generation script is not executable."
  echo
  echo "Run:"
  echo "chmod +x ${INVENTORY_SCRIPT}"
  exit 1
fi

echo "========================================"
echo "AWS Kubernetes Infrastructure Creation"
echo "========================================"
echo
echo "Terraform directory : ${TERRAFORM_DIR}"
echo "Project root        : ${PROJECT_ROOT}"
echo

# 현재 공인 IP 조회
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

# Terraform 초기화
echo "[2/8] Initializing Terraform..."

terraform -chdir="${TERRAFORM_DIR}" init

echo

# Terraform 파일 포맷
echo "[3/8] Formatting Terraform files..."

terraform -chdir="${TERRAFORM_DIR}" fmt -recursive

echo

# Terraform 구성 검증
echo "[4/8] Validating Terraform configuration..."

terraform -chdir="${TERRAFORM_DIR}" validate

echo

# Terraform 실행 계획 생성
echo "[5/8] Creating Terraform execution plan..."

terraform -chdir="${TERRAFORM_DIR}" plan \
  -out="${PLAN_FILE}" \
  -var="my_ip_cidr=${MY_IP_CIDR}"

echo

# Terraform 적용
echo "[6/8] Applying Terraform execution plan..."

terraform -chdir="${TERRAFORM_DIR}" apply \
  "${PLAN_FILE}"

echo

# Ansible Inventory 생성
echo "[7/8] Generating Ansible inventory..."

"${INVENTORY_SCRIPT}"

# Generate Ansible Variables
echo "[8/8] Generate Ansible Variables"

"${SCRIPT_DIR}/generate_ansible_vars.sh"

echo
echo "========================================"
echo "Infrastructure creation completed"
echo "========================================"
echo
echo "Next commands:"
echo
echo "  cd ${PROJECT_ROOT}/ansible"
echo "  ansible all -m ping"
echo "  ansible-playbook site.yml"
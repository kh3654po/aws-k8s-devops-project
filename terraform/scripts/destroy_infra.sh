#!/usr/bin/env bash

set -euo pipefail

# 현재 스크립트 위치:
# <PROJECT_ROOT>/terraform/scripts/destroy_infra.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Terraform 파일이 있는 디렉토리
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# 프로젝트 root 디렉토리
PROJECT_ROOT="$(cd "${TERRAFORM_DIR}/.." && pwd)"

# Terraform Destroy Plan 파일
PLAN_FILE="${TERRAFORM_DIR}/destroy.tfplan"

# 인프라 삭제 후 제거할 Ansible Inventory
INVENTORY_FILE="${PROJECT_ROOT}/ansible/inventory.ini"

# true이면 사용자 확인 없이 삭제
AUTO_APPROVE="${AUTO_APPROVE:-false}"

# 스크립트 종료 시 임시 Plan 파일 제거
cleanup() {
  rm -f "${PLAN_FILE}"
}

trap cleanup EXIT

# 필수 명령어 확인
for required_command in terraform curl; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Error: ${required_command} command was not found."
    exit 1
  fi
done

# Terraform 디렉토리 확인
if [[ ! -d "${TERRAFORM_DIR}" ]]; then
  echo "Error: Terraform directory was not found."
  echo "Path: ${TERRAFORM_DIR}"
  exit 1
fi

echo "========================================"
echo "AWS Kubernetes Infrastructure Destruction"
echo "========================================"
echo
echo "Terraform directory : ${TERRAFORM_DIR}"
echo "Project root        : ${PROJECT_ROOT}"
echo

# 현재 Mac 공인 IP 조회
echo "[1/6] Detecting current public IP..."

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
echo "[2/6] Initializing Terraform..."

terraform -chdir="${TERRAFORM_DIR}" init

echo

# Terraform 구성 검증
echo "[3/6] Validating Terraform configuration..."

terraform -chdir="${TERRAFORM_DIR}" validate

echo

# Terraform State 확인
echo "[4/6] Checking Terraform state..."

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
  fi

  exit 0
fi

echo "Terraform-managed resources:"
echo "${STATE_RESOURCES}"
echo

# Destroy Plan 생성
echo "[5/6] Creating Terraform destroy plan..."

terraform -chdir="${TERRAFORM_DIR}" plan \
  -destroy \
  -out="${PLAN_FILE}" \
  -var="my_ip_cidr=${MY_IP_CIDR}"

echo

# 삭제 확인
if [[ "${AUTO_APPROVE}" != "true" ]]; then
  echo "WARNING: All Terraform-managed infrastructure will be destroyed."
  echo
  read -r -p "Type 'destroy' to continue: " CONFIRMATION

  if [[ "${CONFIRMATION}" != "destroy" ]]; then
    echo
    echo "Infrastructure destruction was cancelled."
    exit 0
  fi
fi

echo

# Destroy Plan 적용
echo "[6/6] Destroying Terraform infrastructure..."

terraform -chdir="${TERRAFORM_DIR}" apply \
  "${PLAN_FILE}"

echo

# Terraform 삭제 성공 후 기존 Inventory 제거
if [[ -f "${INVENTORY_FILE}" ]]; then
  rm -f "${INVENTORY_FILE}"

  echo "Removed Ansible inventory:"
  echo "${INVENTORY_FILE}"
  echo
fi

echo "========================================"
echo "Infrastructure destruction completed"
echo "========================================"
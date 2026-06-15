#!/usr/bin/env bash

set -euo pipefail

# 현재 스크립트의 위치를 기준으로 프로젝트 root 경로 계산
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

TERRAFORM_DIR="${PROJECT_ROOT}/terraform"
INVENTORY_FILE="${PROJECT_ROOT}/ansible/inventory.ini"

# 환경변수가 없으면 기본값 사용
ANSIBLE_USER="${ANSIBLE_USER:-ubuntu}"
SSH_PRIVATE_KEY_PATH="${SSH_PRIVATE_KEY_PATH:-${HOME}/.ssh/aws-kh3654po.pem}"

# 필수 명령어 설치 여부 확인
for required_command in terraform jq; do
  if ! command -v "${required_command}" >/dev/null 2>&1; then
    echo "Error: ${required_command} command was not found."
    exit 1
  fi
done

# Terraform 디렉토리 확인
if [[ ! -d "${TERRAFORM_DIR}" ]]; then
  echo "Error: Terraform directory was not found: ${TERRAFORM_DIR}"
  exit 1
fi

# SSH private key 확인
if [[ ! -f "${SSH_PRIVATE_KEY_PATH}" ]]; then
  echo "Error: SSH private key was not found: ${SSH_PRIVATE_KEY_PATH}"
  echo "Set a different path with SSH_PRIVATE_KEY_PATH."
  exit 1
fi

# Terraform Output 조회
MASTER_PUBLIC_IP="$(
  terraform -chdir="${TERRAFORM_DIR}" output -raw master_public_ip
)"

WORKER_PRIVATE_IPS_JSON="$(
  terraform -chdir="${TERRAFORM_DIR}" output -json worker_private_ips
)"

# master public IP 검증
if [[ -z "${MASTER_PUBLIC_IP}" ]]; then
  echo "Error: master_public_ip Terraform output is empty."
  exit 1
fi

# worker_private_ips가 JSON 배열인지 검증
if ! jq -e 'type == "array"' >/dev/null <<< "${WORKER_PRIVATE_IPS_JSON}"; then
  echo "Error: worker_private_ips Terraform output is not a JSON array."
  exit 1
fi

WORKER_COUNT="$(jq 'length' <<< "${WORKER_PRIVATE_IPS_JSON}")"

if (( WORKER_COUNT == 0 )); then
  echo "Error: No worker private IPs were found."
  exit 1
fi

# worker 배열을 Ansible Inventory host 형식으로 변환
WORKER_HOSTS="$(
  jq -r '
    to_entries[]
    | "worker\(.key + 1) ansible_host=\(.value)"
  ' <<< "${WORKER_PRIVATE_IPS_JSON}"
)"

# Ansible 디렉토리가 없으면 생성
mkdir -p "$(dirname "${INVENTORY_FILE}")"

# inventory.ini 생성
cat > "${INVENTORY_FILE}" <<EOF
[masters]
master ansible_host=${MASTER_PUBLIC_IP}

[workers]
${WORKER_HOSTS}

[k8s:children]
masters
workers

[all:vars]
ansible_user=${ANSIBLE_USER}
ansible_ssh_private_key_file=${SSH_PRIVATE_KEY_PATH}
ansible_ssh_common_args='-o IdentitiesOnly=yes'

[workers:vars]
ansible_ssh_common_args='-o IdentitiesOnly=yes -o ProxyCommand="ssh -i ${SSH_PRIVATE_KEY_PATH} -o IdentitiesOnly=yes -W %h:%p ${ANSIBLE_USER}@${MASTER_PUBLIC_IP}"'
EOF

# Inventory에는 접속 정보가 포함되므로 소유자만 읽고 쓸 수 있도록 설정
chmod 600 "${INVENTORY_FILE}"

echo "Ansible inventory was generated successfully."
echo
echo "Inventory file : ${INVENTORY_FILE}"
echo "Master IP      : ${MASTER_PUBLIC_IP}"
echo "Worker count   : ${WORKER_COUNT}"
echo
echo "Generated workers:"
echo "${WORKER_HOSTS}"
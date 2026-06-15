# AWS Self-Managed Kubernetes with Terraform and Ansible

Terraform으로 AWS 인프라를 생성하고, Ansible과 kubeadm을 사용하여 self-managed Kubernetes cluster를 자동 구축하는 프로젝트입니다.

이 프로젝트는 다음 과정을 자동화합니다.

```text
Terraform
  ↓
VPC, Subnet, NAT Gateway, Security Group, EC2 생성
  ↓
Ansible
  ↓
containerd 및 Kubernetes 패키지 설치
  ↓
Control Plane 초기화
  ↓
Calico CNI 설치
  ↓
Worker Node Join
  ↓
nginx Workload 배포 및 Service 통신 검증
```

---

## 1. 프로젝트 목표

이 프로젝트의 주요 목표는 다음과 같습니다.

* Terraform을 사용한 AWS 인프라 프로비저닝
* Public/Private Subnet을 활용한 Kubernetes node 구성
* Ansible을 사용한 서버 내부 설정 자동화
* kubeadm 기반 self-managed Kubernetes cluster 구축
* Calico CNI를 통한 Pod 네트워크 구성
* Worker node 자동 join
* nginx Deployment와 ClusterIP Service를 통한 cluster 동작 검증
* 인프라를 삭제한 뒤에도 동일한 환경을 재현할 수 있는 자동화 구성

---

## 2. Architecture

AWS 서울 리전의 2개 Availability Zone에 Public/Private Subnet을 구성하고, kubeadm 기반 Kubernetes cluster를 배포합니다.

| 구분                 | 배치 위치                 |                   네트워크 | 수량 | 역할                                            |
| ------------------ | --------------------- | ---------------------: | -: | --------------------------------------------- |
| VPC                | AWS `ap-northeast-2`  |          `10.0.0.0/16` |  1 | 전체 인프라 네트워크                                   |
| Internet Gateway   | VPC                   |                      - |  1 | Public Subnet의 인터넷 통신                         |
| Public Subnet A    | `ap-northeast-2a`     |        `10.0.101.0/24` |  1 | Control Plane 및 NAT Gateway 배치                |
| Public Subnet B    | `ap-northeast-2b`     |        `10.0.102.0/24` |  1 | NAT Gateway 배치                                |
| Private Subnet A   | `ap-northeast-2a`     |          `10.0.1.0/24` |  1 | Worker Node 1 배치                              |
| Private Subnet B   | `ap-northeast-2b`     |          `10.0.2.0/24` |  1 | Worker Node 2 배치                              |
| NAT Gateway        | 각 Public Subnet       |           Public IP 사용 |  2 | Private Subnet의 아웃바운드 인터넷 통신                  |
| Control Plane Node | Public Subnet A       | Private IP + Public IP |  1 | Kubernetes API Server 및 control plane 구성요소 실행 |
| Worker Node        | 각 Private Subnet      |             Private IP |  2 | Kubernetes workload 실행                        |
| Calico Pod Network | Kubernetes cluster 내부 |       `192.168.0.0/16` |  - | Pod IP 할당 및 Pod 간 네트워크                        |
| Service Network    | Kubernetes cluster 내부 |         `10.96.0.0/12` |  - | ClusterIP Service 가상 IP 할당                    |

### Node placement

| Node          | Availability Zone | Subnet           | Public IP | 주요 역할                                           |
| ------------- | ----------------- | ---------------- | --------- | ----------------------------------------------- |
| Control Plane | `ap-northeast-2a` | Public Subnet A  | 할당        | API Server, Scheduler, Controller Manager, etcd |
| Worker 1      | `ap-northeast-2a` | Private Subnet A | 미할당       | Pod 및 application workload 실행                   |
| Worker 2      | `ap-northeast-2b` | Private Subnet B | 미할당       | Pod 및 application workload 실행                   |

### Access flow

| 출발지          | 목적지               | 접근 방식                                           | 용도                             |
| ------------ | ----------------- | ----------------------------------------------- | ------------------------------ |
| Mac          | Control Plane     | Public IP를 통한 SSH                               | Kubernetes 관리 및 Ansible 실행     |
| Mac          | Worker Nodes      | Control Plane을 경유한 SSH ProxyCommand             | Ansible을 통한 worker 설정          |
| Worker Nodes | Internet          | Private Subnet → NAT Gateway → Internet Gateway | Package 및 container image 다운로드 |
| Worker Nodes | Control Plane     | VPC 내부 private network                          | Kubernetes API Server 통신       |
| Pod          | Pod               | Calico CNI                                      | Pod 간 통신                       |
| Pod          | ClusterIP Service | CoreDNS 및 kube-proxy                            | Kubernetes Service 접근          |

현재는 학습과 초기 자동화를 위해 Control Plane node를 worker node 접속 경유지로 사용합니다. 추후 AWS Systems Manager Session Manager, 전용 Bastion Host 또는 VPN 기반 접근 방식으로 개선할 예정입니다.

---

## 3. Network Configuration

| 구분               | CIDR             | 용도                          |
| ---------------- | ---------------- | --------------------------- |
| AWS VPC          | `10.0.0.0/16`    | EC2 node 네트워크               |
| Public Subnet A  | `10.0.101.0/24`  | Control Plane 및 NAT Gateway |
| Public Subnet B  | `10.0.102.0/24`  | NAT Gateway                 |
| Private Subnet A | `10.0.1.0/24`    | Worker Node                 |
| Private Subnet B | `10.0.2.0/24`    | Worker Node                 |
| Pod Network      | `192.168.0.0/16` | Calico Pod IP               |
| Service Network  | `10.96.0.0/12`   | Kubernetes ClusterIP        |

Node, Pod, Service 네트워크는 서로 겹치지 않도록 구성합니다.

---

## 4. Technology Stack

### Infrastructure

* AWS
    * EC2
    * VPC
    * Public/Private Subnet
    * NAT Gateway
    * Security Group
* Terraform
    * terraform-aws-modules/vpc/aws


### Configuration Management

* Ansible
    * Ansible Playbook
* SSH ProxyCommand

### Kubernetes

* Ubuntu 24.04 LTS
* containerd
* kubeadm
* kubelet
* kubectl
* Calico CNI
* Tigera Operator

### Verification

* nginx
* ClusterIP Service
* curl test Pod

---

## 5. Prerequisites

로컬 환경에 다음 도구가 필요합니다.

* AWS CLI
* Terraform
* Ansible
* jq
* SSH key pair
* AWS 계정 및 EC2 생성 권한

macOS에서는 Homebrew로 설치할 수 있습니다.

```bash
brew install awscli
brew install terraform
brew install ansible
brew install jq
```

설치 확인

```bash
aws --version
terraform version
ansible --version
jq --version
```

---

## 6. AWS CLI Configuration

AWS CLI profile을 설정합니다.

```bash
aws configure --profile default
```

Terraform provider에서는 아래 profile을 사용합니다.

```hcl
provider "aws" {
  region  = var.region
  profile = var.awscli_profile
}
```

기본 region은 서울 리전입니다.

```hcl
variable "region" {
  default = "ap-northeast-2"
}
```

---

## 7. SSH Key Pair

Terraform에서 사용할 AWS EC2 Key Pair가 미리 생성되어 있어야 합니다.

예:

```text
AWS Key Pair Name:
aws-kh3654po

Local Private Key:
~/.ssh/aws-kh3654po.pem
```

private key 권한을 설정합니다.

```bash
chmod 400 ~/.ssh/aws-kh3654po.pem
```

---

## 8. Create AWS Infrastructure

Terraform 디렉토리로 이동합니다.

```bash
cd terraform
```

현재 공인 IP를 확인합니다.

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)
echo "${MY_IP}"
```

문법 및 형식 검사

```bash
terraform fmt
terraform validate
```

실행 계획 생성

```bash
terraform plan \
  -out=tfplan \
  -var="my_ip_cidr=${MY_IP}/32"
```

적용

```bash
terraform apply tfplan
```

또는 프로젝트에 포함된 스크립트를 사용할 수 있습니다.

```bash
./scripts/create_infra.sh
```

---

## 9. Terraform Outputs

인프라 생성 후 output을 확인합니다.

```bash
terraform output
```

주요 output:

```text
master_public_ip
master_private_ip
worker_private_ips
```

개별 조회:

```bash
terraform output -raw master_public_ip
terraform output -raw master_private_ip
terraform output -json worker_private_ips
```

---

## 10. Configure Ansible Inventory

예시 inventory를 복사합니다.

```bash
cd ../ansible
cp inventory.example.ini inventory.ini
```

Terraform output을 이용해 실제 IP를 입력합니다.

예시:

```ini
[masters]
master ansible_host=<MASTER_PUBLIC_IP>

[workers]
worker1 ansible_host=<WORKER_1_PRIVATE_IP>
worker2 ansible_host=<WORKER_2_PRIVATE_IP>

[k8s:children]
masters
workers

[all:vars]
ansible_user=ubuntu
ansible_python_interpreter=/usr/bin/python3
ansible_ssh_private_key_file=~/.ssh/<YOUR_PRIVATE_KEY>.pem
ansible_ssh_common_args='-o IdentitiesOnly=yes'

[workers:vars]
ansible_ssh_common_args='-o IdentitiesOnly=yes -o ProxyCommand="ssh -i ~/.ssh/<YOUR_PRIVATE_KEY>.pem -o IdentitiesOnly=yes -W %h:%p ubuntu@<MASTER_PUBLIC_IP>"'
```

현재 inventory는 정적으로 관리하지만, 추후 Terraform output 기반 자동 생성 또는 AWS EC2 Dynamic Inventory로 개선할 예정입니다.

---

## 11. Test Ansible Connectivity

전체 node 연결 확인:

```bash
ansible all -m ping
```

정상 결과:

```text
master  | SUCCESS
worker1 | SUCCESS
worker2 | SUCCESS
```

sudo 권한 확인:

```bash
ansible all -b -m command -a "whoami"
```

모든 node에서 아래 결과가 출력되어야 합니다.

```text
root
```

---

## 12. Build Kubernetes Cluster

통합 playbook을 실행합니다.

```bash
ansible-playbook site.yml
```

`site.yml`은 아래 playbook을 순서대로 실행합니다.

```text
common.yml
  ↓
master.yml
  ↓
workers.yml
```

### `common.yml`

모든 Kubernetes node에 공통 설정을 적용합니다.

* cloud-init 완료 대기
* swap 비활성화
* overlay, br_netfilter module 활성화
* sysctl 설정
* containerd 설치
* systemd cgroup driver 설정
* kubeadm, kubelet, kubectl 설치
* Kubernetes package hold

### `master.yml`

Control Plane을 초기화합니다.

* kubeadm init
* kubeconfig 설정
* Kubernetes API Server 대기
* Calico CRD 설치
* Tigera Operator 설치
* Calico custom resources 적용
* worker join command 생성

### `workers.yml`

Worker node를 cluster에 추가합니다.

* fresh join command 생성
* 기존 join 여부 확인
* kubeadm join
* kubelet 활성화
* 전체 node 상태 확인

---

## 13. Verify Kubernetes Cluster

Node 상태 확인

```bash
ansible masters -m command -a "kubectl get nodes -o wide"
```

전체 Pod 상태 확인

```bash
ansible masters -m command -a "kubectl get pods -A"
```

Calico 상태 확인

```bash
ansible masters -m command \
  -a "kubectl get pods -n calico-system -o wide"
```

Worker kubelet 상태 확인

```bash
ansible workers -b -m command \
  -a "systemctl is-active kubelet"
```

---

## 14. Test nginx Workload

nginx workload 검증 playbook을 실행합니다.

```bash
ansible-playbook test-nginx.yml
```

이 playbook은 다음 작업을 수행합니다.

```text
devops-test Namespace 생성
  ↓
nginx Deployment 생성
  ↓
nginx Pod 3개 생성
  ↓
ClusterIP Service 생성
  ↓
curl test Pod 생성
  ↓
Service DNS 및 네트워크 통신 검증
```

테스트 리소스 확인

```bash
ansible masters -m command \
  -a "kubectl get all -n devops-test"
```

Pod 배치 상태 확인

```bash
ansible masters -m command \
  -a "kubectl get pods -n devops-test -o wide"
```

curl test 결과 확인

```bash
ansible masters -m command \
  -a "kubectl logs curl-test -n devops-test"
```

정상이라면 아래가 포함된 문자열이 출력됩니다.

```text
Welcome to nginx!
```

---

## 15. Cleanup Test Workload

기본적으로 테스트 리소스는 삭제하지 않습니다.

```yaml
# test-nginx.yml
cleanup_after_test: false
```

테스트 실행 후 자동 삭제하려면 extra variable을 전달합니다.

```bash
ansible-playbook test-nginx.yml \
  -e cleanup_after_test=true
```

기존 리소스만 삭제하려면 다음 명령을 실행합니다.

```bash
ansible masters -m command \
  -a "kubectl delete namespace devops-test"
```

---

## 16. Destroy AWS Infrastructure

Terraform 디렉토리로 이동합니다.

```bash
cd ../terraform
```

현재 Mac 공인 IP를 변수로 전달하여 삭제합니다.

```bash
MY_IP=$(curl -s https://checkip.amazonaws.com)

terraform destroy \
  -var="my_ip_cidr=${MY_IP}/32"
```

또는 삭제 스크립트를 사용합니다.

```bash
./scripts/destroy_infra.sh
```

삭제 후 확인

```bash
terraform show
```

---

## 17. Full Execution Flow

전체 실행 순서는 다음과 같습니다.

```bash
# 1. AWS 인프라 생성
cd terraform
./scripts/create_infra.sh

# 2. Ansible inventory 갱신
cd ../ansible
cp inventory.example.ini inventory.ini
vi inventory.ini

# 3. SSH 연결 확인
ansible all -m ping

# 4. Kubernetes cluster 자동 구축
ansible-playbook site.yml

# 5. nginx workload 검증
ansible-playbook test-nginx.yml

# 6. 테스트 리소스 삭제
ansible-playbook test-nginx.yml \
  -e cleanup_after_test=true

# 7. AWS 인프라 삭제
cd ../terraform
./scripts/destroy_infra.sh
```

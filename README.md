# AWS Self-Managed Kubernetes with Terraform

Terraform으로 AWS VPC와 EC2 인프라를 구성하고, kubeadm을 사용하여 self-managed Kubernetes 클러스터를 구축하는 프로젝트입니다.

## Architecture

- VPC: 10.0.0.0/16
- Public Subnet: master node
- Private Subnet: worker nodes
- NAT Gateway: one per AZ
- Kubernetes: kubeadm
- CNI: Calico
#!/usr/bin/env bash
set -euxo pipefail

# 1. swap 비활성화
swapoff -a
sed -i '/ swap / s/^/#/' /etc/fstab

# 2. Kubernetes 네트워크에 필요한 커널 모듈 활성화
tee /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

# 3. sysctl 설정
tee /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system

# 4. containerd 설치
apt update
apt install -y containerd apt-transport-https ca-certificates curl gpg

# 5. containerd 기본 설정 생성
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# 6. containerd systemd cgroup driver 활성화
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable --now containerd

# 7. Kubernetes apt repository 추가
mkdir -p -m755 /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.36/deb/Release.key \
  | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.36/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list


# 8. kubelet, kubeadm, kubectl 설치
apt update
apt install -y kubelet kubeadm kubectl

# 9. 자동 업그레이드로 버전이 바뀌지 않도록 hold
apt-mark hold kubelet kubeadm kubectl

# 10. kubelet 활성화
systemctl enable --now kubelet

# 11. 설치 확인
containerd --version
kubeadm version
kubectl version --client
kubelet --version

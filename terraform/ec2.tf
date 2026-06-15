data "aws_ami" "ubuntu_2404" {
  most_recent = true

  owners = ["099720109477"] # Canonical의 AWS 계정 ID

  # AMI 이름 패턴을 필터링하여 Ubuntu 24.04 LTS 이미지를 선택
  filter {
    name = "name"
    values = [
      "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
    ]
  }

  # 추가 필터링 조건을 통해 x86_64 아키텍처, HVM 가상화 유형, EBS 루트 디바이스 유형, 사용 가능한 상태의 AMI만 선택하도록 설정
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Kubernetes Master Node
resource "aws_instance" "master" {
  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = var.instance_type

  # master는 첫 번째 public subnet에 생성
  subnet_id = module.vpc.public_subnets[0]

  # public subnet에 있으므로 public IP 할당
  associate_public_ip_address = true

  # Kubernetes Master Node는 클러스터의 API 서버 역할을 하므로, 다른 노드에서 Master Node로 트래픽이 올 수 있도록 source_dest_check를 false로 설정하여 네트워크 트래픽이 원활하게 흐르도록 함
  source_dest_check = false

  # 보안 그룹 설정
  vpc_security_group_ids = [aws_security_group.k8s.id]

  # 기존에 AWS에 생성되어 있는 Key Pair 이름
  key_name = var.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.prefix}-k8s-master"
    Role = "master"
  }
}

# Kubernetes Worker Nodes
resource "aws_instance" "worker" {
  count = var.worker_count

  ami           = data.aws_ami.ubuntu_2404.id
  instance_type = var.instance_type

  # 각 private subnet에 worker 생성
  subnet_id = module.vpc.private_subnets[
    count.index % length(module.vpc.private_subnets)
  ]

  # private subnet이므로 public IP 미할당
  associate_public_ip_address = false

  # Kubernetes Worker Node는 클러스터의 워커 역할을 하므로, Master Node와 통신이 원활하게 이루어질 수 있도록 source_dest_check를 false로 설정하여 네트워크 트래픽이 원활하게 흐르도록 함 
  source_dest_check = false

  # 보안 그룹 설정
  vpc_security_group_ids = [aws_security_group.k8s.id]
  key_name               = var.key_name

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.prefix}-k8s-worker-${count.index + 1}"
    Role = "worker"
  }
}
resource "aws_security_group" "k8s" {
  name   = "${var.prefix}-k8s-sg"
  vpc_id = module.vpc.vpc_id

  tags = {
    Name = "${var.prefix}-k8s-sg"
  }
}

# 내 Mac 공인 IP에서 master로 SSH 접속 허용
resource "aws_vpc_security_group_ingress_rule" "ssh_from_my_ip" {
  security_group_id = aws_security_group.k8s.id

  ip_protocol = "tcp"
  from_port   = 22
  to_port     = 22

  cidr_ipv4 = var.my_ip_cidr
}

# Kubernetes 노드끼리 같은 보안 그룹 내부 통신 전체 허용
resource "aws_vpc_security_group_ingress_rule" "k8s_nodes_internal_all" {
  security_group_id = aws_security_group.k8s.id

  ip_protocol = "-1"

  # 같은 보안 그룹을 참조하여 노드끼리 전체 통신 허용 (보안 그룹 체이닝 사용)
  referenced_security_group_id = aws_security_group.k8s.id
}

# 외부로 나가는 트래픽 전체 허용
resource "aws_vpc_security_group_egress_rule" "egress_all" {
  security_group_id = aws_security_group.k8s.id

  ip_protocol = "-1"
  cidr_ipv4   = "0.0.0.0/0"
}
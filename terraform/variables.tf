variable "region" {
  default = "ap-northeast-2"
}

variable "awscli_profile" {
  default = "default"
}

variable "prefix" {
  default = "ksh"
}

variable "key_name" {
  type    = string
  default = "aws-kh3654po"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}

variable "worker_count" {
  type    = number
  default = 3
}

variable "my_ip_cidr" {
  type = string
}

variable "cluster_name" {
  type    = string
  default = "ksh-k8s"
}

variable "worker_asg_instance_type" {
  type    = string
  default = "t3.medium"
}

variable "worker_asg_root_volume_size" {
  type    = number
  default = 20
}

variable "worker_asg_min_size" {
  type    = number
  default = 0
}

variable "worker_asg_desired_capacity" {
  type    = number
  default = 0
}

variable "worker_asg_max_size" {
  type    = number
  default = 3
}

variable "worker_asg_health_check_grace_period" {
  type    = number
  default = 300
}

variable "ssm_join_command_parameter" {
  type    = string
  default = "/ksh/k8s/join-command"
}

variable "kubernetes_apt_version" {
  type    = string
  default = "v1.36"
}

variable "nodeport_test_port" {
  type    = number
  default = 30080
}
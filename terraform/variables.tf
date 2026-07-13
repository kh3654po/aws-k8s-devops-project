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
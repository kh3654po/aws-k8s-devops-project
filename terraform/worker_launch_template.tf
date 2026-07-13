resource "aws_iam_role" "worker_asg" {
  name = "${var.prefix}-worker-asg-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-worker-asg-role"
    Project = var.cluster_name
  }
}

resource "aws_iam_policy" "worker_asg_bootstrap" {
  name = "${var.prefix}-worker-asg-bootstrap-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadBootstrapParameters"
        Effect = "Allow"

        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]

        Resource = [
          "arn:aws:ssm:${var.region}:*:parameter/${var.prefix}/k8s/*"
        ]
      },
      {
        Sid    = "DecryptBootstrapParameters"
        Effect = "Allow"

        Action = [
          "kms:Decrypt"
        ]

        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-worker-asg-bootstrap-policy"
    Project = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "worker_asg_bootstrap" {
  role       = aws_iam_role.worker_asg.name
  policy_arn = aws_iam_policy.worker_asg_bootstrap.arn
}

resource "aws_iam_instance_profile" "worker_asg" {
  name = "${var.prefix}-worker-asg-instance-profile"
  role = aws_iam_role.worker_asg.name

  tags = {
    Name    = "${var.prefix}-worker-asg-instance-profile"
    Project = var.cluster_name
  }
}

resource "aws_launch_template" "worker" {
  name_prefix = "${var.prefix}-k8s-worker-"

  image_id      = data.aws_ami.ubuntu_2404.id
  instance_type = var.worker_asg_instance_type

  key_name = var.key_name

  vpc_security_group_ids = [
    aws_security_group.k8s.id
  ]

  user_data = base64encode(
    templatefile(
      "${path.module}/templates/worker-bootstrap.sh.tftpl",
      {
        cluster_name               = var.cluster_name
        region                     = var.region
        ssm_join_command_parameter = var.ssm_join_command_parameter
        kubernetes_apt_version     = var.kubernetes_apt_version
      }
    )
  )

  iam_instance_profile {
    name = aws_iam_instance_profile.worker_asg.name
  }

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.worker_asg_root_volume_size
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name                                        = "${var.prefix}-k8s-asg-worker"
      Role                                        = "worker"
      Project                                     = var.cluster_name
      "kubernetes.io/cluster/${var.cluster_name}" = "owned"
    }
  }

  tag_specifications {
    resource_type = "volume"

    tags = {
      Name    = "${var.prefix}-k8s-asg-worker-volume"
      Project = var.cluster_name
    }
  }

  tags = {
    Name    = "${var.prefix}-k8s-worker-launch-template"
    Project = var.cluster_name
  }

  lifecycle {
    create_before_destroy = true
  }
}
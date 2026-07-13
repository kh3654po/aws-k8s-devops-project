resource "aws_autoscaling_group" "worker" {
  name = "${var.prefix}-k8s-worker-asg"

  min_size         = var.worker_asg_min_size
  desired_capacity = var.worker_asg_desired_capacity
  max_size         = var.worker_asg_max_size

  vpc_zone_identifier = module.vpc.private_subnets

  health_check_type         = "EC2"
  health_check_grace_period = var.worker_asg_health_check_grace_period

  protect_from_scale_in = false

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  termination_policies = [
    "OldestInstance"
  ]

  tag {
    key                 = "Name"
    value               = "${var.prefix}-k8s-asg-worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.cluster_name
    propagate_at_launch = true
  }

  tag {
    key                 = "kubernetes.io/cluster/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/enabled"
    value               = "true"
    propagate_at_launch = true
  }

  tag {
    key                 = "k8s.io/cluster-autoscaler/${var.cluster_name}"
    value               = "owned"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [
      desired_capacity
    ]
  }
}
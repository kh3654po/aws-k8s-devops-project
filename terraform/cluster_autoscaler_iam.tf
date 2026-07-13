data "aws_caller_identity" "current" {}

resource "aws_iam_role" "master" {
  name = "${var.prefix}-master-role"

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
    Name    = "${var.prefix}-master-role"
    Project = var.cluster_name
  }
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name = "${var.prefix}-cluster-autoscaler-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadAutoScalingAndEc2Metadata"
        Effect = "Allow"

        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeScalingActivities",
          "ec2:DescribeImages",
          "ec2:DescribeInstanceTypes",
          "ec2:DescribeLaunchTemplateVersions",
          "ec2:GetInstanceTypesFromInstanceRequirements"
        ]

        Resource = "*"
      },
      {
        Sid    = "ScaleWorkerAutoScalingGroup"
        Effect = "Allow"

        Action = [
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup"
        ]

        Resource = [
          "arn:aws:autoscaling:${var.region}:${data.aws_caller_identity.current.account_id}:autoScalingGroup:*:autoScalingGroupName/${aws_autoscaling_group.worker.name}"
        ]
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-cluster-autoscaler-policy"
    Project = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  role       = aws_iam_role.master.name
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
}

resource "aws_iam_instance_profile" "master" {
  name = "${var.prefix}-master-instance-profile"
  role = aws_iam_role.master.name

  tags = {
    Name    = "${var.prefix}-master-instance-profile"
    Project = var.cluster_name
  }
}
resource "aws_iam_policy" "aws_cloud_controller_manager" {
  name = "${var.prefix}-aws-cloud-controller-manager-policy"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ReadAwsCloudMetadata"
        Effect = "Allow"

        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeRegions",
          "ec2:DescribeAvailabilityZones",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeRouteTables",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeTags",
          "ec2:DescribeInstanceTopology",
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances"
        ]

        Resource = "*"
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-aws-cloud-controller-manager-policy"
    Project = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "aws_cloud_controller_manager" {
  role       = aws_iam_role.master.name
  policy_arn = aws_iam_policy.aws_cloud_controller_manager.arn
}
resource "aws_iam_role" "worker" {
  name = "${var.prefix}-worker-role"

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
    Name    = "${var.prefix}-worker-role"
    Project = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "worker_ebs_csi" {
  role       = aws_iam_role.worker.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEBSCSIDriverPolicyV2"
}

resource "aws_iam_instance_profile" "worker" {
  name = "${var.prefix}-worker-instance-profile"
  role = aws_iam_role.worker.name

  tags = {
    Name    = "${var.prefix}-worker-instance-profile"
    Project = var.cluster_name
  }
}
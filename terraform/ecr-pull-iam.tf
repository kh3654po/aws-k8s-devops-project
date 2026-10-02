data "aws_iam_policy_document" "worker_ecr_pull" {
  statement {
    sid    = "GetECRAuthorizationToken"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid    = "PullImageFromProjectECR"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer"
    ]

    resources = [
      aws_ecr_repository.devops_demo.arn
    ]
  }
}

resource "aws_iam_policy" "worker_ecr_pull" {
  name = "${var.prefix}-worker-ecr-pull-policy"

  policy = data.aws_iam_policy_document.worker_ecr_pull.json

  tags = {
    Name    = "${var.prefix}-worker-ecr-pull-policy"
    Project = var.cluster_name
    Purpose = "kubernetes-ecr-pull"
  }
}

resource "aws_iam_role_policy_attachment" "worker_ecr_pull" {
  role       = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.worker_ecr_pull.arn
}

resource "aws_iam_role_policy_attachment" "worker_asg_ecr_pull" {
  role       = aws_iam_role.worker_asg.name
  policy_arn = aws_iam_policy.worker_ecr_pull.arn
}
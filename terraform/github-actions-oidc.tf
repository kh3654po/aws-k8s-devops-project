resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  tags = {
    Name    = "${var.prefix}-github-actions-oidc"
    Project = var.cluster_name
    Purpose = "github-actions-oidc"
  }
}

data "aws_iam_policy_document" "github_actions_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRoleWithWebIdentity"
    ]

    principals {
      type = "Federated"

      identifiers = [
        aws_iam_openid_connect_provider.github_actions.arn
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"

      values = [
        "sts.amazonaws.com"
      ]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"

      values = [
        "repo:${var.github_repository}:ref:refs/heads/${var.github_branch}"
      ]
    }
  }
}

resource "aws_iam_role" "github_actions_ci" {
  name = "${var.prefix}-github-actions-ci"

  assume_role_policy = data.aws_iam_policy_document.github_actions_assume_role.json

  max_session_duration = 3600

  tags = {
    Name    = "${var.prefix}-github-actions-ci"
    Project = var.cluster_name
    Purpose = "github-actions-ci"
  }
}

data "aws_iam_policy_document" "github_actions_ecr_push" {
  statement {
    sid    = "GetAuthorizationToken"
    effect = "Allow"

    actions = [
      "ecr:GetAuthorizationToken"
    ]

    resources = [
      "*"
    ]
  }

  statement {
    sid    = "PushImageToRepository"
    effect = "Allow"

    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart"
    ]

    resources = [
      aws_ecr_repository.devops_demo.arn
    ]
  }
}

resource "aws_iam_policy" "github_actions_ecr_push" {
  name = "${var.prefix}-github-actions-ecr-push"

  description = "Allow GitHub Actions to push images to the project ECR repository"

  policy = data.aws_iam_policy_document.github_actions_ecr_push.json

  tags = {
    Name    = "${var.prefix}-github-actions-ecr-push"
    Project = var.cluster_name
    Purpose = "github-actions-ecr-push"
  }
}

resource "aws_iam_role_policy_attachment" "github_actions_ecr_push" {
  role = aws_iam_role.github_actions_ci.name

  policy_arn = aws_iam_policy.github_actions_ecr_push.arn
}
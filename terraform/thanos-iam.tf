resource "aws_iam_policy" "thanos_s3" {
  name        = "${var.prefix}-thanos-s3-policy"
  description = "Allow Thanos components to access long-term metric storage in S3"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "ThanosListBucket"
        Effect = "Allow"

        Action = [
          "s3:ListBucket"
        ]

        Resource = [
          aws_s3_bucket.thanos.arn
        ]
      },
      {
        Sid    = "ThanosObjectAccess"
        Effect = "Allow"

        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]

        Resource = [
          "${aws_s3_bucket.thanos.arn}/*"
        ]
      }
    ]
  })

  tags = {
    Name    = "${var.prefix}-thanos-s3-policy"
    Project = var.cluster_name
    Purpose = "thanos-long-term-metrics"
  }
}

resource "aws_iam_role_policy_attachment" "worker_thanos_s3" {
  role       = aws_iam_role.worker.name
  policy_arn = aws_iam_policy.thanos_s3.arn
}
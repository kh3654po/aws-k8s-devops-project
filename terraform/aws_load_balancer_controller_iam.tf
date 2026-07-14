resource "aws_iam_policy" "aws_load_balancer_controller" {
  name = "${var.prefix}-aws-load-balancer-controller-policy"

  policy = file("${path.module}/policies/aws-load-balancer-controller-iam-policy.json")

  tags = {
    Name    = "${var.prefix}-aws-load-balancer-controller-policy"
    Project = var.cluster_name
  }
}

resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.master.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller.arn
}
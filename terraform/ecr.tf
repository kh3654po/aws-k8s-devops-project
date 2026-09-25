resource "aws_ecr_repository" "devops_demo" {
  name = "${var.prefix}-devops-demo"

  # Commit SHA 기반 Image Tag를 덮어쓰지 못하도록 보호
  image_tag_mutability = "IMMUTABLE"

  # 학습 환경에서 terraform destroy 시
  # Image가 존재해도 Repository를 함께 제거
  force_delete = var.ecr_force_delete

  # Repository에 Image가 Push되면 기본 취약점 Scan 수행
  image_scanning_configuration {
    scan_on_push = true
  }

  # ECR에 저장되는 Image Layer 암호화
  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Name    = "${var.prefix}-devops-demo"
    Project = var.cluster_name
    Purpose = "cicd-container-registry"
  }
}

resource "aws_ecr_lifecycle_policy" "devops_demo" {
  repository = aws_ecr_repository.devops_demo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1

        description = "Expire untagged images after ${var.ecr_untagged_image_retention_days} days"

        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = var.ecr_untagged_image_retention_days
        }

        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2

        description = "Keep only the most recent ${var.ecr_max_image_count} images"

        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = var.ecr_max_image_count
        }

        action = {
          type = "expire"
        }
      }
    ]
  })
}
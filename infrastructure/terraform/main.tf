terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = "us-east-1"
}

locals {
  project = "mlops-showcase"
  owner   = "Rafael Santiago"          
  tags = {
    Project     = local.project
    slv_owner   = local.owner
    slv_stg     = "dev"
    ManagedBy   = "terraform"
  }
}

resource "aws_s3_bucket" "mlops" {
  bucket = "${local.project}-${data.aws_caller_identity.current.account_id}"
  tags   = local.tags
}

resource "aws_s3_bucket_lifecycle_configuration" "mlops" {
  bucket = aws_s3_bucket.mlops.id

  rule {
    id     = "expire-raw-logs"
    status = "Enabled"
    filter { prefix = "logs/" }
    expiration { days = 30 }
  }
}

data "aws_caller_identity" "current" {}

# ECR
resource "aws_ecr_repository" "mlops" {
  name                 = local.project
  image_tag_mutability = "MUTABLE"
  tags                 = local.tags
}

# OIDC Provider — GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

# IAM Role — GitHub Actions → ECR
resource "aws_iam_role" "github_actions" {
  name = "github-actions-${local.project}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:tommmdl/MLOps-Machine-Learning:*"
        }
      }
    }]
  })

  tags = local.tags
}

resource "aws_iam_role_policy" "github_actions_ecr" {
  name = "ecr-push"
  role = aws_iam_role.github_actions.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = aws_ecr_repository.mlops.arn
      }
    ]
  })
}
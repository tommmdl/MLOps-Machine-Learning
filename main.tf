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
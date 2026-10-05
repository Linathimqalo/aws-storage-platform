terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = "us-east-1"
  access_key                  = "flociadmin"
  secret_key                  = "flociadmin"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
  s3_use_path_style           = true

  endpoints {
    s3  = "http://localhost:4566"
    iam = "http://localhost:4566"
    sts = "http://localhost:4566"
  }
}

variable "primary_bucket_name" {
  description = "Name of the primary S3 bucket"
  type        = string
  default     = "terraform-managed-lab"
}

variable "backup_bucket_name" {
  description = "Name of the backup S3 bucket"
  type        = string
  default     = "terraform-managed-backup"
}

resource "aws_s3_bucket" "terraform_lab" {
  bucket = var.primary_bucket_name
}

resource "aws_s3_bucket" "backup_lab" {
  bucket = var.backup_bucket_name
}

resource "aws_s3_bucket_public_access_block" "terraform_lab" {
  bucket = aws_s3_bucket.terraform_lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "backup_lab" {
  bucket = aws_s3_bucket.backup_lab.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_kms_key" "storage_key" {
  description             = "KMS key for S3 storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "storage_key_alias" {
  name          = "alias/storage-lab-key"
  target_key_id = aws_kms_key.storage_key.key_id
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_lab" {
  bucket = aws_s3_bucket.terraform_lab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.storage_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "backup_lab" {
  bucket = aws_s3_bucket.backup_lab.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.storage_key.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_policy" "terraform_lab_deny_public" {
  bucket = aws_s3_bucket.terraform_lab.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "DenyPublicRead"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.terraform_lab.arn}/*"
        Condition = {
          StringNotEquals = {
            "aws:PrincipalAccount" = "000000000000"
          }
        }
      }
    ]
  })
}

resource "aws_iam_user" "audit_reader" {
  name = "audit-reader"
}

resource "aws_iam_policy" "audit_reader_policy" {
  name        = "audit-reader-policy"
  description = "Read-only access to specific S3 buckets"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListSpecificBuckets"
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.terraform_lab.arn,
          aws_s3_bucket.backup_lab.arn
        ]
      },
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.terraform_lab.arn}/*",
          "${aws_s3_bucket.backup_lab.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "audit_reader_attach" {
  user       = aws_iam_user.audit_reader.name
  policy_arn = aws_iam_policy.audit_reader_policy.arn
}
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

# ============================================================
# KMS key (shared across all buckets)
# ============================================================

resource "aws_kms_key" "storage_key" {
  description             = "KMS key for S3 storage encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "storage_key_alias" {
  name          = "alias/storage-lab-key"
  target_key_id = aws_kms_key.storage_key.key_id
}

# ============================================================
# Buckets — created via the secure-bucket module
# ============================================================

module "terraform_lab" {
  source      = "./modules/secure-bucket"
  bucket_name = "terraform-managed-lab"
  kms_key_arn = aws_kms_key.storage_key.arn
  account_id  = "000000000000"
  force_destroy = true

  tags = {
    Project   = "aws-storage-platform"
    ManagedBy = "terraform"
    Purpose   = "primary"
  }
}

module "backup_lab" {
  source      = "./modules/secure-bucket"
  bucket_name = "terraform-managed-backup"
  kms_key_arn = aws_kms_key.storage_key.arn
  account_id  = "000000000000"
  force_destroy = true

  # This bucket is the deliberate-misconfiguration target in Phase 3.
  # It skips the Deny-public policy so we can break it cleanly.
  enable_deny_public_policy = false

  tags = {
    Project   = "aws-storage-platform"
    ManagedBy = "terraform"
    Purpose   = "backup"
  }
}

module "company_storage_lab" {
  source      = "./modules/secure-bucket"
  bucket_name = "company-storage-lab"
  kms_key_arn = aws_kms_key.storage_key.arn
  account_id  = "000000000000"
  force_destroy = true

  tags = {
    Project   = "aws-storage-platform"
    ManagedBy = "terraform"
    Origin    = "phase-1-cli"
  }
}

module "audit_logs_lab" {
  source      = "./modules/secure-bucket"
  bucket_name = "audit-logs-lab"
  kms_key_arn = aws_kms_key.storage_key.arn
  account_id  = "000000000000"
  force_destroy = true

  tags = {
    Project   = "aws-storage-platform"
    ManagedBy = "terraform"
    Origin    = "phase-1-cli"
  }
}

module "practice_bucket_lm" {
  source      = "./modules/secure-bucket"
  bucket_name = "practice-bucket-lm"
  kms_key_arn = aws_kms_key.storage_key.arn
  account_id  = "000000000000"
  force_destroy = true

  tags = {
    Project   = "aws-storage-platform"
    ManagedBy = "terraform"
    Origin    = "phase-1-cli"
  }
}

# ============================================================
# IAM — read-only audit user
# ============================================================

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
        Action = ["s3:ListBucket"]
        Resource = [
          module.terraform_lab.bucket_arn,
          module.backup_lab.bucket_arn
        ]
      },
      {
        Sid    = "ReadObjects"
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "${module.terraform_lab.bucket_arn}/*",
          "${module.backup_lab.bucket_arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_user_policy_attachment" "audit_reader_attach" {
  user       = aws_iam_user.audit_reader.name
  policy_arn = aws_iam_policy.audit_reader_policy.arn
}
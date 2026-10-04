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
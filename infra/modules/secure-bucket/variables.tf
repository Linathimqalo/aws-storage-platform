# modules/secure-bucket/variables.tf

variable "bucket_name" {
  description = "Name of the S3 bucket (must be globally unique)"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key to use for encryption"
  type        = string
}

variable "account_id" {
  description = "AWS account ID, used in the Deny-public policy condition"
  type        = string
}

variable "enable_versioning" {
  description = "Enable object versioning on the bucket"
  type        = bool
  default     = true
}

variable "enable_deny_public_policy" {
  description = "Attach an explicit Deny-public bucket policy"
  type        = bool
  default     = true
}

variable "force_destroy" {
  description = "Allow Terraform to delete the bucket even if non-empty"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
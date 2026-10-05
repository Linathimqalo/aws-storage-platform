# secure-bucket module

Creates an S3 bucket with security controls applied by default.

## What it creates

- S3 bucket
- Block Public Access (all four settings enabled)
- SSE-KMS encryption using a caller-provided KMS key
- Bucket versioning (optional, on by default)
- Explicit Deny-public bucket policy (optional, on by default)

## Usage

    module "example" {
      source      = "./modules/secure-bucket"
      bucket_name = "my-bucket-name"
      kms_key_arn = aws_kms_key.example.arn
      account_id  = "123456789012"

      tags = {
        Project = "example"
      }
    }

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| bucket_name | string | yes | — | Bucket name (globally unique) |
| kms_key_arn | string | yes | — | KMS key ARN for SSE-KMS |
| account_id | string | yes | — | Used in Deny-public policy condition |
| enable_versioning | bool | no | true | Enable object versioning |
| enable_deny_public_policy | bool | no | true | Attach explicit Deny-public policy |
| force_destroy | bool | no | false | Allow deletion of non-empty bucket |
| tags | map(string) | no | {} | Tags applied to the bucket |

## Outputs

| Name | Description |
|---|---|
| bucket_id | Bucket name |
| bucket_arn | Bucket ARN |
| bucket_domain_name | Bucket domain name |

## Design notes

- All four Block Public Access settings are always enabled. There's no
  variable to disable them — that's intentional. Public buckets are a
  security incident waiting to happen.
- Deny-public policy is enabled by default but can be turned off. This
  exists so the module can be used as a deliberate misconfiguration
  target in testing.
- `force_destroy` defaults to false. In production you want Terraform to
  refuse to delete a non-empty bucket. In labs, set it to true.
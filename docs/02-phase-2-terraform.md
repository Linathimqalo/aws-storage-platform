# Phase 2 — Terraform Automation

## Goal

Rebuild the Phase 1 environment declaratively using Terraform. Understand
the difference between imperative commands and declarative infrastructure.

## The mental shift

| AWS CLI | Terraform |
|---|---|
| Imperative ("do this now") | Declarative ("this is what I want to exist") |
| You remember the commands | Files record the desired state |
| No state tracking | State file tracks everything Terraform manages |
| Hard to review changes | Diffs reviewable before applying |
| Manual drift correction | Automatic drift detection and correction |

## Provider configuration

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

Why each part:

- `terraform {}` — declares providers Terraform needs to download
- `provider "aws" {}` — configures how Terraform connects to AWS
- `endpoints {}` — redirects API calls to Floci
- `skip_*` flags — bypass credential validation calls Floci doesn't implement
- `s3_use_path_style` — Floci uses `localhost:4566/bucket`, real AWS uses
  `bucket.s3.amazonaws.com`

## Resources and variables

    variable "primary_bucket_name" {
      description = "Name of the primary S3 bucket"
      type        = string
      default     = "terraform-managed-lab"
    }

    resource "aws_s3_bucket" "terraform_lab" {
      bucket = var.primary_bucket_name
    }

The resource has two names:

- `terraform_lab` — Terraform's internal reference (used elsewhere in config)
- `terraform-managed-lab` — the actual bucket name sent to AWS

Variables centralize configuration so changes happen in one place.

## Terraform commands

| Command | Purpose |
|---|---|
| `terraform init` | Downloads providers, creates `.terraform/` and lock file |
| `terraform plan` | Dry run — shows what would change |
| `terraform apply` | Executes the plan (requires `yes` confirmation) |
| `terraform destroy` | Removes all managed resources |
| `terraform fmt` | Auto-formats files |
| `terraform import` | Attaches existing resource to declared config |
| `terraform init -migrate-state` | Moves state between backends |

## Idempotency — the core property

Running `terraform plan` twice in a row after a successful apply shows:

    No changes. Your infrastructure matches the configuration.

Terraform compares config against state against reality. If they match, it
does nothing. This is why IaC is safer than manual commands — no accidental
duplicates, no forgotten changes.

## Drift detection

Delete a bucket manually:

    aws s3 rb s3://terraform-managed-lab
    terraform plan

Terraform reports it will recreate the bucket — state says it should exist,
reality says otherwise. This is drift detection.

## What we built

- Two buckets: `terraform-managed-lab`, `terraform-managed-backup`
- Both created by Terraform
- Bucket names driven by variables
- State file (`terraform.tfstate`) — never committed, gitignored

## Security observations from the state file

    "grant": [{
      "id": "000000000000",
      "permissions": ["FULL_CONTROL"],
      "type": "CanonicalUser"
    }]

Owner has full control. No public grants. Correct baseline.

    "server_side_encryption_configuration": [{
      "rule": [{
        "apply_server_side_encryption_by_default": [{
          "sse_algorithm": "AES256",
          "kms_master_key_id": ""
        }]
      }]
    }]

Default encryption is AWS-managed `AES256`. No KMS key. This became the
driver for Phase 3.

## Artifacts preserved

In `legacy/phase-2-terraform/`:
- `main.tf` — the final Terraform config
- `README.md` — phase documentation
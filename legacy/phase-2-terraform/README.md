# Phase 2 — Automation (Terraform)

**Goal:** Rebuild the Phase 1 environment declaratively, then extend it.

## What I built

- `aws_s3_bucket.terraform_lab` → `terraform-managed-lab`
- `aws_s3_bucket.backup_lab` → `terraform-managed-backup`

Both buckets are defined as Terraform resources. Names are driven by variables.

## Concepts learned

- **Provider block** — Terraform uses the AWS provider to talk to the AWS API, same as the CLI does
- **Endpoints override** — redirects all AWS API calls to Floci at `localhost:4566`
- **`terraform init`** — downloads the provider, creates `.terraform.lock.hcl`
- **`terraform plan`** — dry-run showing what *would* change
- **`terraform apply`** — executes the plan
- **Idempotency** — re-running `apply` after success produces "no changes"
- **State file** (`terraform.tfstate`) — Terraform's record of what it manages. Not committed to Git.
- **Variables** — centralize configuration; used by resources via `var.name`

## Observations from the state file

The `terraform.tfstate` output showed:
- Bucket ACL: owner has `FULL_CONTROL`, no public grants
- Server-side encryption: default `AES256` (AWS default since 2023)
- No KMS key — that's a Phase 3 improvement

## Environment

- Floci (local AWS emulator)
- Terraform v1.16.x with AWS provider v5.100.0
- Git Bash on Windows

## Next

Phase 3 — apply security controls: Block Public Access, bucket policies,
least-privilege IAM, KMS encryption. Then deliberately break the security
and detect the misconfiguration via CLI audit.
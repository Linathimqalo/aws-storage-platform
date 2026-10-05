# Phase 3 Notes

## What this folder contains

- main.tf — provider, variables, two S3 buckets, and security controls
- terraform.tfstate — Terraform's tracking of these resources

## Relationship to Phase 2

This phase imports the buckets that Phase 2 created, then adds:
- Block Public Access on both buckets
- Customer-managed KMS key
- SSE-KMS encryption on both buckets
- Deny-public bucket policy on primary bucket
- Least-privilege IAM user (audit-reader) with scoped policy

## Important: two state files

`phase-2-terraform/terraform.tfstate` and `phase-3-security/terraform.tfstate`
both track the same buckets but from different folders. This is for teaching
clarity only. Real projects use one folder, one state.

## Commands used

- `terraform import aws_s3_bucket.terraform_lab terraform-managed-lab` — adopt an existing bucket
- `terraform plan` — see what would change
- `terraform apply` — execute the plan
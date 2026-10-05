# Phase 5B — Terraform Modules

## Goal

Extract repeated S3 bucket configuration into a reusable module. Learn
the Terraform patterns that real teams use.

## The problem

`infra/main.tf` had 5 near-identical sets of resource blocks — one per
bucket. Each set included:

- aws_s3_bucket
- aws_s3_bucket_public_access_block
- aws_s3_bucket_server_side_encryption_configuration

That's ~15 resource blocks for what's conceptually one thing repeated.
Any change to the security controls meant editing 5 places.

## The module

Extracted to `infra/modules/secure-bucket/`. It creates a bucket with:

- Block Public Access (always — no variable to disable)
- SSE-KMS encryption
- Optional versioning (count conditional)
- Optional Deny-public policy (count conditional)

## Before vs after

Before: 5 buckets × 5 resources = 25 resource blocks in main.tf.

After: 5 module calls, each ~10 lines. Module internals handle the rest.

## What's new

- **`count` conditionals** — `count = var.enable_versioning ? 1 : 0`
  creates a resource only when a condition is true
- **Module inputs and outputs** — variables pass in, outputs pass out
- **`this` naming convention** — a module that manages one of something
  calls it `this`
- **Tags propagation** — a `map(string)` variable passed to `tags`
- **Default values** — safe defaults for optional variables

## State migration

Moving from top-level resources to module-wrapped resources changes
Terraform's addressing:

- Before: `aws_s3_bucket.terraform_lab`
- After: `module.terraform_lab.aws_s3_bucket.this`

Terraform treats these as different resources. In production, you'd use
`terraform state mv` to reassign addresses without recreating. In this
lab, `terraform destroy` followed by `apply` was faster.

## Verification

- 5 buckets exist in Floci
- All have Block Public Access enabled
- All have SSE-KMS encryption
- Audit script returns 0 findings

## Interview-ready from Phase 5B

- Explain what a Terraform module is and why it exists
- Describe how variables and outputs work in a module
- Explain `count` as a conditional resource creator
- Describe how to handle state when refactoring into modules
- Explain why some variables have defaults and others don't
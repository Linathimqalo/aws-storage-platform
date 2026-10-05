# Phase 3 — Security Controls

## Goal

Apply real security controls to the Terraform-managed environment. Then
deliberately introduce a vulnerability to test detection.

## Controls applied

### 1. Block Public Access on both buckets

    resource "aws_s3_bucket_public_access_block" "terraform_lab" {
      bucket = aws_s3_bucket.terraform_lab.id

      block_public_acls       = true
      block_public_policy     = true
      ignore_public_acls      = true
      restrict_public_buckets = true
    }

The four settings do different things:

| Setting | What it prevents |
|---|---|
| block_public_acls | New public ACLs on objects or bucket |
| ignore_public_acls | Ignores existing public ACLs |
| block_public_policy | Rejects public bucket policies |
| restrict_public_buckets | Blocks cross-account access via public policy |

All four must be enabled for full protection. AWS enables them by default
on new buckets — but not always, and never retroactively on older ones.

### 2. Customer-managed KMS key

    resource "aws_kms_key" "storage_key" {
      description             = "KMS key for S3 storage encryption"
      deletion_window_in_days = 7
      enable_key_rotation     = true
    }

    resource "aws_kms_alias" "storage_key_alias" {
      name          = "alias/storage-lab-key"
      target_key_id = aws_kms_key.storage_key.key_id
    }

Customer-managed keys give control over:

- Who can use the key (via key policy)
- Rotation schedule (yearly by default)
- Auditing every use via CloudTrail
- Revocation by disabling the key

For PCI DSS, HIPAA, or regulated environments, customer-managed keys are
typically required.

### 3. SSE-KMS encryption on both buckets

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

`bucket_key_enabled = true` uses a bucket-level key derived from the KMS key,
reducing KMS API calls by up to 99%.

### 4. Explicit Deny public policy

    resource "aws_s3_bucket_policy" "terraform_lab_deny_public" {
      bucket = aws_s3_bucket.terraform_lab.id

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
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
        }]
      })
    }

`Effect = "Deny"` always wins, even against other Allow policies. Defense
in depth — even if someone adds a public Allow, this Deny blocks it.

### 5. Least-privilege IAM user

    resource "aws_iam_user" "audit_reader" {
      name = "audit-reader"
    }

    resource "aws_iam_policy" "audit_reader_policy" {
      name = "audit-reader-policy"

      policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
          {
            Sid    = "ListSpecificBuckets"
            Effect = "Allow"
            Action = ["s3:ListBucket"]
            Resource = [
              aws_s3_bucket.terraform_lab.arn,
              aws_s3_bucket.backup_lab.arn
            ]
          },
          {
            Sid    = "ReadObjects"
            Effect = "Allow"
            Action = ["s3:GetObject"]
            Resource = [
              "${aws_s3_bucket.terraform_lab.arn}/*",
              "${aws_s3_bucket.backup_lab.arn}/*"
            ]
          }
        ]
      })
    }

Only `ListBucket` and `GetObject` — no write, no delete, no bucket creation.
Resources scoped to two specific buckets, not `*`. This is least privilege
in practice.

## The import problem

Phase 3 started with a copy of Phase 2's `main.tf` in a new folder with an
empty state. Terraform didn't know the buckets existed and tried to create
them. Floci rejected it with `BucketAlreadyOwnedByYou`.

Fix: `terraform import`

    terraform import aws_s3_bucket.terraform_lab terraform-managed-lab
    terraform import aws_s3_bucket.backup_lab terraform-managed-backup

Import adopts existing resources into Terraform's state. Requires the
resource block to already exist in config — that's why the missing
`aws_s3_bucket` blocks had to be added first. Import doesn't discover or
create anything; it attaches an existing resource to a declared config
address.

After import, `terraform plan` showed only the new security resources being
added — no buckets, because Terraform now knew they existed.

## The deliberate misconfiguration drill

### Step 1: Break it

    aws s3api put-public-access-block \
      --bucket terraform-managed-backup \
      --public-access-block-configuration "BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false"

    aws s3api put-bucket-policy \
      --bucket terraform-managed-backup \
      --policy '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":"*","Action":"s3:GetObject","Resource":"arn:aws:s3:::terraform-managed-backup/*"}]}'

Creates a bucket anyone on the internet can read.

### Step 2: Detect via Terraform

    terraform plan

Output:

    ~ resource "aws_s3_bucket_public_access_block" "backup_lab" {
        ~ block_public_acls       = false -> true
        ~ block_public_policy     = false -> true
        ~ ignore_public_acls      = false -> true
        ~ restrict_public_buckets = false -> true
      }

    Plan: 0 to add, 1 to change, 0 to destroy.

Terraform detected drift on Block Public Access because that resource is
declared. It did NOT detect the public policy because no
`aws_s3_bucket_policy` resource was declared for `backup_lab`.

**Critical lesson:** Terraform only manages what's declared. Anything
created outside its scope is invisible to it.

### Step 3: Remediate

    terraform apply

Terraform restored the settings. The public policy was neutralized by the
re-enabled Block Public Access settings.

### Step 4: Detect independently

The audit script iterates every bucket, checks Block Public Access, and
inspects policies for wildcard Allow principals. This is the detection
control that catches things Terraform can't see.

## The Phase 3 audit script bug

The Phase 3 script used `grep` to check for wildcard principals:

    if echo "$policy" | grep -q '\\"Principal\\":\\"\\*\\"'; then

This was fragile — the escaping rules for embedding JSON inside a bash
string don't match the actual output format of the AWS CLI. The check
frequently missed real findings. This became the focus of Phase 4.

## Findings at end of Phase 3

- Terraform-managed buckets: 0 findings
- Legacy Phase 1 buckets (company-storage-lab, audit-logs-lab,
  practice-bucket-lm, testgui, ryan-reynolds): 5 findings, all
  "No Block Public Access configured"

These 5 became the remediation backlog for Phase 4.

## Artifacts preserved

In `legacy/phase-3-security/`:
- `main.tf` — full Terraform config with security controls
- `audit-s3.sh` — the first (buggy) version of the audit script
- `NOTES.md`, `README.md` — phase documentation
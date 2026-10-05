# Phase 1 — CLI Fundamentals

## Goal

Learn to talk to AWS directly through the CLI. Understand what each command
returns. Produce auditable evidence.

## Setup

Every Git Bash session needs these environment variables:

    export AWS_ENDPOINT_URL=http://localhost:4566
    export AWS_ACCESS_KEY_ID=flociadmin
    export AWS_SECRET_ACCESS_KEY=flociadmin
    export AWS_DEFAULT_REGION=us-east-1

| Variable | Purpose |
|---|---|
| AWS_ENDPOINT_URL | Redirects all AWS API calls to the local Floci container |
| AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY | Floci accepts any credentials but the CLI requires them |
| AWS_DEFAULT_REGION | Required by the CLI even though Floci ignores it |

Later added to ~/.bashrc so they load automatically in every new session.

## Commands used

### Identity verification

    aws sts get-caller-identity

Returns the current user's ARN, account ID, and user ID. Always the first
command in any AWS session. Requires no permissions — makes it the go-to
diagnostic when nothing else works.

### IAM — creating and listing users

    aws iam create-user --user-name storage-admin
    aws iam list-users

`list-users` is plural because it returns a list. `create-user` is singular
because it acts on one resource. AWS uses this convention consistently.

### S3 — creating and uploading

    aws s3 mb s3://company-storage-lab
    echo "cloud security lab data" > lab-data.txt
    aws s3 cp lab-data.txt s3://company-storage-lab/lab-data.txt

`mb` = make bucket. `cp` handles local→S3, S3→local, S3→S3.

### S3 — enumeration

    aws s3 ls
    aws s3 ls s3://company-storage-lab/

First lists buckets. Second lists objects in a specific bucket.

### S3 — auditing

    aws s3api get-bucket-acl --bucket company-storage-lab
    aws s3api head-object --bucket audit-logs-lab --key audit-entry.txt

`get-bucket-acl` returns who can access the bucket.
`head-object` returns metadata: size, content type, ETag (MD5 hash),
last-modified timestamp.

### Evidence capture

    aws sts get-caller-identity > step-2-identity.json
    aws iam list-users > step-8-users.json
    aws s3api get-bucket-acl --bucket company-storage-lab > step-7-acl.json

Every command's output saved to a file. This became the raw evidence behind
the phase's findings — the same way a security engineer preserves artifacts
during an audit.

## Key distinction: `s3` vs `s3api`

| High-level (`aws s3`) | Low-level (`aws s3api`) |
|---|---|
| Uses `s3://bucket/key` URLs | Uses raw bucket names and `--key` args |
| Simple operations (cp, ls, mb, rb) | Full API surface |
| Hides some security settings | Exposes everything |

Security work uses `s3api` more because it exposes the settings that matter.

## Security findings from Phase 1

- Freshly created S3 buckets show only the owner with `FULL_CONTROL` — no
  public grants. Correct baseline.
- Default encryption observed in the state file: AWS-managed `AES256`. No
  customer-managed KMS key.
- CLI runs as account root in Floci (`arn:aws:iam::000000000000:root`). In
  real AWS, root should only be used for account-level tasks.

## What we built

- IAM user: `storage-admin`
- S3 bucket: `company-storage-lab`
- Uploaded object: `lab-data.txt`
- A second practice run: IAM user `audit-readonly`, bucket `audit-logs-lab`

## Artifacts preserved

All in `legacy/phase-1-cli/`:
- `step-2-identity.json`, `step-8-users.json`
- `step-6-buckets.txt`, `step-6-objects.txt`
- `step-7-acl.json`, `step-7b-acl-audit.json`, `step-7b-head-object.json`
- Various text files representing uploaded objects
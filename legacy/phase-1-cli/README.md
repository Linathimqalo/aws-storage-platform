# AWS Storage Platform

A progressive AWS engineering project built in Floci (local AWS emulator).
Each phase adds a layer: manual provisioning → automation → security → operations.

## Phase 1 — Foundation (CLI)

**Goal:** Understand AWS CLI fundamentals against a local AWS environment.

**What I built:**
- IAM user: `storage-admin`
- S3 bucket: `company-storage-lab`
- Uploaded object: `lab-data.txt`

**Commands practiced:**
- `aws sts get-caller-identity` — verify identity and connectivity
- `aws iam create-user` — create IAM identity
- `aws s3 mb` — create bucket
- `aws s3 cp` — upload object
- `aws s3 ls` — enumerate buckets and objects
- `aws s3api get-bucket-acl` — audit bucket access
- `aws iam list-users` — enumerate identities

**Security observation:**
Bucket ACL showed only owner with `FULL_CONTROL` — no public grants.
This is the correct baseline that Phase 3 will deliberately break and remediate.

**Environment:** Floci (local AWS emulator), AWS CLI v2, Git Bash on Windows.

**Next:** Phase 2 — rebuild this environment with Terraform.

## Practice Notes

### Errors I made and what they taught me

- **`aws iam list-user`** → the correct command is `list-users`. AWS uses plural for enumeration operations.
- **`aws s3api get-buckets-acl`** → the correct command is `get-bucket-acl`. Singular when operating on one bucket.
- **`--bucket s3://practice-bucket-lm`** → `s3api` commands use the raw bucket name, not the `s3://` URL. The scheme is only used by high-level `aws s3` commands.

### Commands I can now run without looking up

| Task | Command |
|---|---|
| Who am I? | `aws sts get-caller-identity` |
| List buckets | `aws s3 ls` |
| List objects | `aws s3 ls s3://bucket-name/` |
| Create bucket | `aws s3 mb s3://bucket-name` |
| Upload file | `aws s3 cp local.txt s3://bucket/` |
| Create IAM user | `aws iam create-user --user-name name` |
| List users | `aws iam list-users` |
| Inspect bucket access | `aws s3api get-bucket-acl --bucket name` |
| Inspect object metadata | `aws s3api head-object --bucket name --key file` |

### Observation

The bucket ACL on a freshly created bucket shows only the owner with `FULL_CONTROL`. No public grants. This is the correct baseline — Phase 3 will deliberately break it and remediate it.
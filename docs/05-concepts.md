# Concept Reference

Every concept used in this project, explained in plain language.

## AWS concepts

### IAM (Identity and Access Management)

The system that controls who can do what in AWS. Users represent
identities. Policies attach to users, groups, or roles. Policies contain
statements that Allow or Deny actions on resources. Explicit Deny always
wins over Allow.

### S3 (Simple Storage Service)

Object storage. Buckets hold objects. Buckets have globally unique names.
Objects have keys, metadata, and an ETag (MD5 hash).

### Block Public Access

Four settings that prevent S3 buckets from being made public. Enabled by
default on new buckets since April 2023. The four settings each address a
different vector.

### KMS (Key Management Service)

Manages encryption keys. Customer-managed keys give control over rotation,
access, and audit.

### SSE-KMS

Server-side encryption using KMS. Alternative to SSE-S3 (AWS-managed
AES256). More control, more auditability, slightly higher cost.

### STS (Security Token Service)

Issues temporary credentials. `get-caller-identity` uses it to report who
you are.

### ARN (Amazon Resource Name)

Globally unique identifier for any AWS resource. Format:
`arn:aws:service:region:account:resource`.

### Account root

The original identity of an AWS account. Unrestricted access. Best
practice: use only for account-level tasks, never for daily work.

## Terraform concepts

### Provider

A plugin that lets Terraform talk to a platform (AWS, Azure, GCP).
Configured in `provider` blocks.

### Resource

A single managed object. Declared with `resource "type" "local_name" {}`.

### Variable

A parameterized value. Declared with `variable "name" {}`, referenced as
`var.name`.

### State file

Terraform's record of what it manages. Maps config resource addresses to
real-world resource IDs. Never edit by hand. Never commit to Git.

### Plan

A dry run. Shows what Terraform would do without doing it.

### Apply

Executes the plan. Requires confirmation.

### Idempotency

Running the same config twice produces the same result. Second run is a
no-op.

### Drift

When reality diverges from config. Terraform detects it during `plan` and
proposes a fix.

### Import

Attaches an existing resource to a declared config block. Requires the
config block to exist first.

### Backend

Where state is stored. Local by default, S3 for remote.

### Remote state

State stored in a shared location. Enables team collaboration and prevents
loss.

### Module

Reusable Terraform code. Not used here, but the next logical step.

## Security concepts

### Least privilege

Grant only the permissions needed for the task. Scope actions and resources
tightly.

### Defense in depth

Multiple layers of controls. Block Public Access + Deny policy + audit
script means no single failure exposes data.

### Explicit Deny

In IAM, `Deny` overrides any `Allow`. Used as the last line of defense.

### Drift detection

Noticing when reality diverges from intended state. Terraform does this
declaratively. Audit scripts do it independently.

### Detection engineering

Writing reliable checks that catch real problems. Requires testing the
detector itself against both positive and negative cases.

### Incident response lifecycle

Detect → triage → contain → investigate → remediate → document. NIST
standard.

### Adopting existing resources

Bringing unmanaged resources under IaC control. `terraform import` handles
this.

## Git concepts

### Commit

Snapshot of changes with a message.

### Branch

Independent line of work. Default branch is `main` on modern projects.

### Remote

A URL pointing to a shared repository (usually GitHub).

### Push

Uploading local commits to the remote.

### Force push (--force)

Overwrites remote history. Safe for solo practice, dangerous on shared
branches.

### .gitignore

Files Git should not track. `.tfstate` and audit reports belong here.

### Rename detection

Git notices when a file moves. `git mv` preserves history better than
delete-and-recreate.
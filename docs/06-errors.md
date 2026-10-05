# Errors and Lessons

Every error encountered during the project, and what it taught.

## CLI errors

### `aws iam list-user` (singular)

The correct command is `list-users`. AWS uses plural for enumeration
operations that return lists.

**Lesson:** Read the CLI's "Maybe you meant:" suggestions. They're almost
always right.

### `aws s3api get-buckets-acl`

The correct command is `get-bucket-acl`. Singular when acting on one
resource.

**Lesson:** Naming reflects the API's design — singular vs plural
distinguishes one-thing from many-things.

### `--bucket s3://practice-bucket-lm`

`aws s3api` commands use raw bucket names, not the `s3://` URL scheme.
The scheme is only used by high-level `aws s3` commands.

**Lesson:** High-level commands think in URLs. Low-level commands think
in identifiers.

## Shell errors

### `Out-File` (PowerShell) in Git Bash

`Out-File` is PowerShell syntax. In Git Bash, use `>` for redirection.

**Lesson:** Different shells use different syntax. Stick to one — Git Bash
for cloud work.

### `echo %USERNAME%` in Git Bash

`%VAR%` is Windows CMD syntax. In Bash, it's `$USERNAME` or `${USERNAME}`.

**Lesson:** Environment variable syntax varies by shell.

### `[200~` in pasted commands

Bracketed paste markers can leak into the command line when copying from
some terminals. The command fails as `bash: [200~aws: command not found`.

**Lesson:** If you see `[200~` at the start of a command, retype it or
paste again.

## Terraform errors

### `BucketAlreadyOwnedByYou`

Terraform tried to create a bucket that already exists. This happens when
state is empty but reality has the resource.

**Lesson:** Use `terraform import` to adopt existing resources. State and
reality must agree before apply.

### `Reference to undeclared resource`

Config references `aws_s3_bucket.terraform_lab` but the resource block is
missing. This happened when copying `main.tf` between phases and dropping
the bucket blocks.

**Lesson:** When copying `.tf` files between folders, verify the copy is
complete. Real projects use modules to avoid this.

### Nested `.git` folders

A repo inside a repo. Git warns: `adding embedded git repository`.

**Lesson:** Wherever `.git/` lives, that folder (and everything below) is
the repo. Never nest repos accidentally.

### Deprecated backend parameters

Terraform warned about `endpoint` and `force_path_style` in the S3 backend
config. Newer syntax: `endpoints.s3` and `use_path_style`.

**Lesson:** Terraform evolves. Read warnings and update. They exist
because old syntax will eventually be removed.

## Tooling errors

### `jq: command not found`

Git Bash on Windows doesn't ship with jq. Install via winget:
`winget install jqlang.jq`.

**Lesson:** Verify tools are installed before building scripts that
depend on them.

### Fake jq from bad download URL

An attempted download from a GitHub URL returned HTML instead of the
binary, creating a file that claimed to be `jq` but was a web page.

**Lesson:** Verify download URLs. Use official sources. If a binary
suddenly outputs HTML, it's not a binary.

## Detection engineering errors

### Audit script false negative

The Phase 3 audit script's grep pattern didn't match the actual output
format of `aws s3api get-bucket-policy`. Public policies went undetected.

**Lesson:** Test detection tools against both positive and negative cases.
Your detector needs its own testing.

## Meta-lessons

1. **Every error is a gap in understanding.** When something fails, ask
   what assumption was wrong.

2. **The CLI's error messages are usually right.** Read them slowly.

3. **Console copy-paste is fragile.** Terminal paste markers, escaping,
   and shells all vary.

4. **State management is the hardest part of Terraform.** Local vs
   remote, state vs reality, drift vs config. Most real problems live here.

5. **Detection tools need testing.** The bug that launched Phase 4 was
   in the detector, not the detection target.
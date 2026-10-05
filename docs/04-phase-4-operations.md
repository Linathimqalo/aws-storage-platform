# Phase 4 — Operations & Detection

## Goal

Move from "build and secure" into "monitor and respond." Fix the detection
bug from Phase 3. Bring legacy buckets under management. Establish remote
state and documentation.

## Fixing the detection bug

The Phase 3 check was:

    if echo "$policy" | grep -q '\\"Principal\\":\\"\\*\\"'; then

The Phase 4 check:

    has_wildcard=$(echo "$policy_raw" | jq '
      [.Statement[] | select(.Effect == "Allow") | select(.Principal == "*")] | length
    ' 2>/dev/null)

    if [ "$has_wildcard" -gt 0 ]; then
      echo "  CRITICAL: Public policy with wildcard principal (Allow)"
      bucket_findings+=("public_policy_wildcard_allow")
    fi

Why this works: `jq` parses JSON as structured data. No escaping ambiguity.
The filter is more precise — catches `Effect == "Allow"` with
`Principal == "*"` and ignores the safe case of `Effect == "Deny"` with a
wildcard principal.

Verified against both cases:

- Deny policy on `terraform-managed-lab` → 0 findings (correct)
- Allow policy on `terraform-managed-backup` → 1 finding (correct)

## The restructured repo

Before Phase 4, each phase had its own folder with its own `.tf` and
`.tfstate`. Phase 4 consolidated:

    aws-storage-platform/
    ├── README.md
    ├── .gitignore
    ├── infra/                      # Terraform — single source of truth
    │   ├── main.tf
    │   ├── backend.tf              # gitignored (contains credentials)
    │   └── backend.tf.example
    ├── scripts/
    │   └── audit-s3.sh
    ├── reports/                    # Audit output (gitignored)
    ├── docs/
    │   ├── phase-4.md
    │   └── incident-response.md
    └── legacy/
        ├── phase-1-cli/
        ├── phase-2-terraform/
        ├── phase-3-security/
        └── phase-4-operations/

Git preserved history via renames. The `phase-1-cli` folder became
`legacy/phase-1-cli`, and Git shows this as a rename (100% identical
content), not a delete-and-recreate.

## Legacy bucket adoption

Three Phase 1 buckets were CLI-created and unmanaged. Phase 4:

1. Declared them as `aws_s3_bucket` resources
2. Imported each one:

       terraform import aws_s3_bucket.company_storage_lab company-storage-lab
       terraform import aws_s3_bucket.audit_logs_lab audit-logs-lab
       terraform import aws_s3_bucket.practice_bucket_lm practice-bucket-lm

3. Added `aws_s3_bucket_public_access_block` resources for each
4. Applied — Terraform added the Block Public Access settings

Two experimental buckets (testgui, ryan-reynolds) were deleted:

    aws s3 rm s3://testgui --recursive
    aws s3 rb s3://testgui

## Remote state

State was moved from local file to S3:

    terraform {
      backend "s3" {
        bucket = "terraform-state-storage"
        key    = "storage-platform/terraform.tfstate"
        region = "us-east-1"

        endpoints = {
          s3 = "http://localhost:4566"
        }

        access_key                  = "flociadmin"
        secret_key                  = "flociadmin"
        skip_credentials_validation = true
        skip_metadata_api_check     = true
        skip_region_validation      = true
        use_path_style              = true
      }
    }

Migration:

    terraform init -migrate-state

Terraform prompted whether to copy existing state to the new backend.
`yes` moved the state file into S3.

**Why remote state matters:**

- Local state can be lost with the laptop
- Two engineers applying simultaneously would corrupt each other's work
  (locking solves this on real AWS)
- State can contain sensitive data — keeping it in a controlled S3 bucket
  with restricted access is safer than scattered laptops

**Credentials:** `backend.tf` is gitignored. A `backend.tf.example`
template is committed with credentials commented out.

## The final audit

    === S3 Security Audit ===

    --- company-storage-lab ---
    --- audit-logs-lab ---
    --- terraform-managed-lab ---
    --- practice-bucket-lm ---
    --- terraform-managed-backup ---
    --- terraform-state-storage ---

    === Audit complete ===
    Total findings: 0

Six buckets, zero findings. Every bucket managed by Terraform, all with
Block Public Access enabled, no public policies.

## Documentation

Three files written:

- `docs/incident-response.md` — full workflow for responding to an S3
  exposure finding
- `docs/phase-4.md` — the phase summary
- `README.md` — the top-level repo overview

## The audit script structure

The final script:

1. Lists all buckets
2. For each bucket, checks Block Public Access (all four settings)
3. For each bucket, checks policies for Allow + wildcard Principal
4. Accumulates findings into a JSON array
5. Writes a timestamped report to `reports/audit-<timestamp>.json`
6. Appends a summary line to `reports/audit.log`
7. Exits with code 1 if findings exist (CI/CD can fail on this)

## Interview-ready from Phase 4

- Explain why detection tooling needs its own testing
- Describe how Terraform drift detection works and where it has blind spots
- Explain the value of remote state and locking
- Describe a full incident response workflow for an S3 exposure
- Explain why separating detection from remediation matters
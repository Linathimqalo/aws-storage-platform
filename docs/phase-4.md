# Phase 4 — Operations & Detection

## Goal

Move from "build and secure" into "monitor and respond." Establish the
detection and operations layer that turns infrastructure into a
maintainable, auditable system.

## What was built

- Audit script with reliable JSON parsing (jq)
- Timestamped JSON reports per run (reports/audit-<timestamp>.json)
- Rolling audit log (reports/audit.log)
- Repo restructured: infra/, scripts/, reports/, docs/, legacy/
- Legacy Phase 1 buckets imported into Terraform management
- Experimental buckets deleted (testgui, ryan-reynolds)
- Remote state (S3 backend at terraform-state-storage)
- Incident response workflow documented

## Detection bug fix

Phase 3's audit script used a fragile grep pattern to detect public
bucket policies. Phase 4 rewrote the check using jq:

[.Statement[] | select(.Effect == "Allow") | select(.Principal == "*")] | length

This filters for the dangerous combination (Allow + wildcard Principal)
and ignores the safe case (Deny + wildcard Principal). Verified against
both cases.

## Repo restructure

Before Phase 4, each phase had its own folder with its own .tf and
.tfstate. Phase 4 consolidated:

- infra/ — single Terraform folder, single state
- scripts/ — operational scripts
- reports/ — output of audit runs (gitignored)
- docs/ — persistent documentation
- legacy/ — earlier phase configs as historical evidence

## Legacy bucket adoption

Three Phase 1 buckets (company-storage-lab, audit-logs-lab,
practice-bucket-lm) were CLI-created and unmanaged. Phase 4 declared
them as Terraform resources, imported them, and applied Block Public
Access via aws_s3_bucket_public_access_block.

## Remote state

State was moved from a local file to S3:
- Backend: s3://terraform-state-storage/storage-platform/terraform.tfstate
- Credentials externalized (not committed)
- Template at infra/backend.tf.example

## Audit result at end of Phase 4

Total findings: 0. Every bucket is managed by Terraform, has Block
Public Access enabled, and has no public policies.

## Interview-ready from Phase 4

- Explain why detection tooling needs its own testing
- Describe how Terraform drift detection works and where it has blind spots
- Explain the value of remote state and locking
- Describe a full incident response workflow for an S3 exposure
- Explain why separating detection from remediation matters
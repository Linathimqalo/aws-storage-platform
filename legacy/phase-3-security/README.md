## Audit results

### Findings on first run

The audit script found 5 findings:
- `testgui`, `company-storage-lab`, `audit-logs-lab`, `practice-bucket-lm`, `ryan-reynolds` — no Block Public Access configured

These are Phase 1 CLI-created buckets. They were created before security controls were applied. **Known remediation backlog — Phase 4 will import them under Terraform management and apply controls.**

### Deliberate misconfiguration drill

1. Disabled Block Public Access on `terraform-managed-backup` via CLI
2. Added a public bucket policy with `Principal: *`
3. Ran `terraform plan` — detected drift on Block Public Access settings, proposed restoration
4. Ran `terraform apply` — restored all four settings to `true`
5. Ran the audit script — caught the 4 settings, but **missed the public policy**

### Known bug in the audit script

The public-policy detection regex doesn't match the actual output format of `aws s3api get-bucket-policy`. **This is a real detection-engineering lesson**: your detector itself needs testing. Fix scheduled for Phase 4.

### After remediation

`terraform plan` returns "No changes." Audit script returns 5 findings (the Phase 1 backlog).
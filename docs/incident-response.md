# Incident Response — S3 Public Exposure

## Scope

This document describes the response workflow when the S3 audit
(`scripts/audit-s3.sh`) reports a finding. It mirrors the standard
NIST incident response lifecycle: detect, contain, investigate, remediate,
document.

## Detection

- Scheduled audit: `scripts/audit-s3.sh` runs on a schedule
- Findings written to `reports/audit-<timestamp>.json`
- Rolling log appended to `reports/audit.log`
- Exit code is non-zero when findings exist — CI/CD and monitoring
  systems can alert on this

## Triage (within 15 minutes of alert)

1. Read the finding report:
   cat reports/audit-<timestamp>.json | jq .
2. Identify affected bucket(s) and finding type(s):
   - no_public_access_block_configured — bucket has no controls
   - <Setting>_disabled — specific Block Public Access setting is off
   - public_policy_wildcard_allow — CRITICAL: policy with Allow + Principal:"*"
3. Confirm the finding manually:
   aws s3api get-public-access-block --bucket <name>
   aws s3api get-bucket-policy --bucket <name>

## Containment (immediate)

Remediate at the source. Two paths:

Fast path (CLI):
   aws s3api delete-bucket-policy --bucket <name>
   aws s3api put-public-access-block --bucket <name> \
     --public-access-block-configuration \
     "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Correct path (Terraform):
   cd infra
   terraform plan
   terraform apply

Why prefer Terraform: it restores the state declared in code. Manual CLI
fixes work but leave the environment inconsistent with what Terraform
believes. Verify with terraform plan after any CLI fix.

## Investigation (within 24 hours)

Who made the change?
- In production: CloudTrail event PutBucketPolicy or PutPublicAccessBlock
- Fields: userIdentity.arn, sourceIPAddress, eventTime, requestParameters
- Filter: aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=PutBucketPolicy

What was their intent?
- If a known engineer: likely accidental. Interview them.
- If unknown identity: treat as potential compromise. Escalate.

Was data accessed?
- S3 server access logs (if enabled) show GetObject requests
- Filter for requests from IPs outside the account's known ranges
- CloudTrail data events (if enabled) provide per-object access logs

When did it happen?
- CloudTrail gives exact timestamps
- Correlate with other events (credential changes, network activity)

## Remediation (prevention)

If accidental (developer error):
- Retrain the individual
- Add SCP at AWS Organizations level to deny s3:PutBucketPolicy with public principals
- Enforce Block Public Access at account level

If malicious:
- Revoke the IAM credentials used
- Rotate any other keys the identity has access to
- Enable MFA enforcement
- Review for lateral movement

Either way:
- Confirm the fix is in Terraform config
- Run terraform plan to verify no drift
- Run scripts/audit-s3.sh to confirm 0 findings

## Post-mortem

- Timeline of events (detection, triage, containment, resolution)
- Root cause
- What detection caught
- What detection missed
- Action items with owners and deadlines

## Floci limitations

Floci does not provide CloudTrail data events or S3 server access logs.
In real AWS, investigation uses:
- CloudTrail (management events, always on)
- CloudTrail data events (opt-in per bucket)
- S3 server access logs (opt-in per bucket)
- GuardDuty S3 protection
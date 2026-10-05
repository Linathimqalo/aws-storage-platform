# AWS Storage Platform

A progressive AWS engineering and security project built in Floci (local AWS emulator).
Each phase adds a layer: manual provisioning → automation → security → operations.

## Phases

| Phase | Focus | Location |
|-------|-------|----------|
| 1 | CLI fundamentals | legacy/phase-1-cli/ |
| 2 | Terraform automation | legacy/phase-2-terraform/ |
| 3 | Security controls | legacy/phase-3-security/ |
| 4 | Operations & detection | docs/phase-4.md |

## Current state

- Infrastructure: infra/ — single Terraform folder, remote state
- Detection: scripts/audit-s3.sh
- Reports: reports/ — audit output (gitignored)
- Documentation: docs/

## Security posture

5 S3 buckets, all:
- Managed by Terraform
- Block Public Access enabled (all four settings)
- SSE-KMS encrypted with a customer-managed key
- No public bucket policies

Audit findings at time of writing: 0

## Environment

- Floci — local AWS emulator
- AWS CLI v2 — configured with AWS_ENDPOINT_URL=http://localhost:4566
- Terraform v1.x — AWS provider v5.x, S3 remote state
- jq — JSON parsing for audit script
- Git Bash on Windows

## Repo structure

aws-storage-platform/
├── README.md
├── .gitignore
├── infra/                    # Terraform — single source of truth
│   ├── main.tf
│   ├── backend.tf            # gitignored
│   └── backend.tf.example
├── scripts/
│   └── audit-s3.sh
├── reports/
├── docs/
│   ├── phase-4.md
│   └── incident-response.md
└── legacy/
    ├── phase-1-cli/
    ├── phase-2-terraform/
    ├── phase-3-security/
    └── phase-4-operations/

## Running

Terraform:
    cd infra
    terraform init
    terraform plan
    terraform apply

Audit:
    ./scripts/audit-s3.sh
# AWS Storage Platform

A progressive AWS engineering project built in Floci (local AWS emulator).
Each phase adds a layer: manual provisioning → automation → security → operations.

## Phases

| Phase | Focus | Folder |
|-------|-------|--------|
| 1 | CLI fundamentals | [`phase-1-cli/`](./phase-1-cli/) |
| 2 | Terraform automation | [`phase-2-terraform/`](./phase-2-terraform/) |
| 3 | Security controls & audit | [`phase-3-security/`](./phase-3-security/) |
| 4 | Operations & detection (upcoming) | `phase-4-operations/` |

## Environment

- **Floci** — local AWS emulator (S3, IAM, STS)
- **AWS CLI v2** — configured with `AWS_ENDPOINT_URL=http://localhost:4566`
- **Terraform v1.x** — AWS provider pointed at Floci
- **Git Bash on Windows**
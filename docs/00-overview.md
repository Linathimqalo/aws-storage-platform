# Project Overview

## The premise

A progressive AWS engineering and security project built in Floci (local
AWS emulator). Structured as four phases, each adding a layer of engineering
maturity.

Most cloud tutorials show you how to create resources. Very few show you how to:

- Understand why each resource exists
- Break security controls on purpose to test detection
- Adopt existing unmanaged resources into infrastructure-as-code
- Move state to remote storage safely
- Document a realistic incident-response workflow

This project does all five, progressively.

## Technical summary

- **Environment:** Floci (local AWS emulator) in Docker on Windows
- **Tools:** AWS CLI v2, Terraform v1.16, jq, Git Bash
- **Resources:** 5 S3 buckets, 2 IAM users, 2 IAM policies, 1 KMS key + alias,
  5 Block Public Access configs, 2 SSE-KMS encryption configs, 1 explicit
  Deny bucket policy
- **Detection:** Custom Bash audit script checking every bucket for public exposure
- **State:** Remote S3 backend
- **Documentation:** Incident-response workflow, per-phase summaries, this folder

## The four phases

| Phase | Focus | What it added |
|---|---|---|
| 1 | CLI fundamentals | Manual bucket/user creation, evidence capture |
| 2 | Terraform automation | Declarative infrastructure, variables, state |
| 3 | Security controls | Block Public Access, KMS, Deny policies, misconfiguration drill |
| 4 | Operations & detection | Fixed audit script, remote state, incident response docs |

## Why phases and not one big project

Each phase teaches a distinct skill. Phase boundaries force the question:
"what did this phase actually add?" That's the discipline that makes
progress visible — both for learning and for portfolio storytelling.

## Timeline

Built over four sessions:
- Sessions 1 (Phases 1–2): CLI, then Terraform
- Session 2 (Phase 3): Security controls and misconfiguration
- Sessions 3–4 (Phase 4): Detection fix, restructure, remote state, docs

## The most valuable lesson

Deliberately introducing a public S3 policy to test detection exposed a bug
in the detection script itself. Fixing that bug taught more about detection
engineering than any tutorial could. **Your detectors need testing too.**

## What this project does not include

- Real AWS deployment (Floci used throughout)
- CI/CD integration (Phase 5 scope)
- Compute, networking, or non-storage services
- GuardDuty, Config, or Macie integration

These are natural extensions, not gaps.
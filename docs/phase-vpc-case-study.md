# AWS VPC Network Security — Case Study

*Three-tier VPC design with defence-in-depth network controls, built in Floci and managed with Terraform.*

---

## Executive Summary

This project documents the design and build of a three-tier VPC in AWS, with layered network security controls — routing isolation, security groups, network ACLs, and VPC Flow Logs — all managed declaratively through Terraform.

The environment segments resources into public, private-application, and private-data tiers. Each tier has a distinct routing profile and its own firewall controls. Tier-to-tier access is identity-based (security group references), not IP-based. The data tier has no internet route at all — the network-layer equivalent of physically isolating the database.

After building the secure baseline, I deliberately introduced three misconfigurations to test detection:

1. Opened SSH (port 22) on the public security group to the internet
2. Opened PostgreSQL (port 5432) on the data security group to the internet
3. Replaced the data NACL's app-subnet CIDR rule with `0.0.0.0/0`

A custom Bash audit script detected all three. Remediation was done two ways — first via CLI for speed, then via `terraform apply` to restore declarative state. The environment returned to 0 findings, and `terraform plan` returned "No changes."

The project demonstrates the full network security lifecycle: **design → build → harden → break → detect → remediate → verify.**

---

## Architecture

```
VPC: 10.0.0.0/16
│
├── Public Subnet (10.0.1.0/24)
│   ├── Route: 0.0.0.0/0 → Internet Gateway
│   ├── Security Group: public-sg
│   └── NACL: public-nacl
│
├── Private App Subnet (10.0.10.0/24)
│   ├── Route: 0.0.0.0/0 → NAT Gateway
│   └── Security Group: app-sg (accepts traffic from public-sg only)
│
└── Private Data Subnet (10.0.20.0/24)
    ├── Route: none (no internet access)
    ├── Security Group: data-sg (accepts traffic from app-sg only, no egress)
    └── NACL: data-nacl (only app subnet CIDR can reach)
```

**Why three tiers:**

- **Public** — resources that must be reachable from the internet. Load balancers, bastion hosts. Minimal surface — only the ports that need to be open are open.
- **Private App** — application servers. They need outbound internet (package updates, API calls), but shouldn't be reachable inbound.
- **Private Data** — databases. No internet access in any direction. Reachable only from the application tier.

This is standard AWS architecture. It shows up in almost every production environment, and it's asked about in interviews.

---

## Security Design Decisions

### Decision 1: Publicness is determined by routes, not by name

The *public* and *private* labels in AWS are informal. A subnet is "public" if and only if its route table has a route to an Internet Gateway.

The subnets themselves have different flags — `map_public_ip_on_launch` is `true` for the public subnet and `false` for the private subnets — but that flag is a convenience, not the definition. If you attach a route to an IGW to a subnet whose instances don't have public IPs, those instances still aren't reachable — but any instances you later assign public IPs to would be. And if a subnet has no route to the IGW, public IPs assigned to instances do nothing.

**Why this matters:** Misunderstanding the mechanism is a common source of exposures. "I set it to private" often means "I didn't map public IPs on launch" — which is not the same as "no internet access." The route table is the actual control.

### Decision 2: The data tier has no default route

```hcl
resource "aws_route_table" "private_data" {
  vpc_id = aws_vpc.main.id
  # No 0.0.0.0/0 route
}
```

Traffic to anywhere outside the VPC has no route in the data subnet. It's dropped at the routing layer, before any firewall would even need to evaluate it.

**Why this is powerful:** Even if every security group and NACL in the data tier was misconfigured to allow all traffic, the routing table would still prevent internet connectivity. Defence in depth starts at the routing layer. It's the cheapest, most reliable control — because it can't be "opened accidentally" by changing a port number. You have to deliberately add a route.

> **Interview-grade insight:** When someone asks "how do you prevent a database from reaching the internet?" the answer isn't "put it in a private subnet." The answer is: **no default route.** Subnet names are cosmetic; the routing table is enforcement.

### Decision 3: The app tier has outbound-only internet via NAT

```hcl
resource "aws_route_table" "private_app" {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
}
```

Application servers need outbound internet (to fetch packages, call APIs, reach AWS services). They don't need to be reachable inbound. A NAT Gateway provides exactly that.

**How it works:** The app server's route table sends internet-bound traffic to the NAT. The NAT translates the source IP to its own public IP and forwards it. The response comes back to the NAT, which forwards it back to the app server. The app server has no public IP and no path for someone on the internet to reach it.

### Decision 4: Tier-to-tier access uses security group references

```hcl
resource "aws_security_group" "app" {
  ingress {
    from_port       = 8080
    to_port         = 8080
    security_groups = [aws_security_group.public.id]
  }
}
```

**Not** `cidr_blocks = ["10.0.1.0/24"]`.

This means: "Allow traffic on port 8080 from any instance that has the `public-sg` security group attached." It's identity-based, not address-based.

**Why identity-based is preferred:**

- If you add a second load balancer to the public tier, it automatically gets access. No config change.
- If you remove the public SG from an instance, it loses access instantly. No stale IPs.
- Adding a monitoring instance in the public subnet doesn't accidentally grant it access to the app tier. Only instances with the SG do.

**The API representation:** When you inspect the security group, this rule appears under `UserIdGroupPairs` instead of `IpRanges`. That's the difference between an identity-based rule and an address-based rule. Interviewers ask about this distinction.

### Decision 5: The data tier security group has no egress rules

```hcl
resource "aws_security_group" "data" {
  ingress {
    description     = "Database traffic from app tier only"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }
  # No egress block
}
```

Databases don't initiate connections. They respond to them. Removing egress rules entirely is a security control: even if an attacker gains code execution on the database, it can't reach out.

**The layered effect:** Combined with the no-route decision above, the data tier has two independent controls preventing outbound connections — the routing table and the SG. Both must be bypassed to allow exfiltration.

---

## The Misconfiguration Drill

After building the secure baseline, I deliberately introduced three misconfigurations that mirror real-world incidents.

### Break 1: SSH open to the world

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-9d724360e71bc3b40 \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0
```

**What this does:** Adds a rule to `public-sg` allowing SSH from any IP on the internet.

**Why it matters:** This is the single most-scanned AWS misconfiguration. Automated scanners find open SSH within minutes of exposure and attempt brute-force. The Storage project covered this same class of exposure with S3. It recurs here because it's the same underlying mistake — a default-safe configuration accidentally opened up.

**The correct baseline:** The `public-sg` config declares SSH from `10.0.0.0/16` (the VPC CIDR, a placeholder for a real bastion/VPN source). Opening it to `0.0.0.0/0` is the misconfiguration.

### Break 2: PostgreSQL open to the world

```bash
aws ec2 authorize-security-group-ingress \
  --group-id sg-2d32eb3364902f43e \
  --protocol tcp \
  --port 5432 \
  --cidr 0.0.0.0/0
```

**What this does:** Adds a rule to `data-sg` allowing PostgreSQL from any IP.

**Why it matters:** This bypasses the entire tiered architecture. The database is now reachable from the internet, regardless of the routing design or the NACL. The security group was the last line of defence, and it's been opened.

This is the scenario the whole design exists to prevent. Seeing it get through one layer — while the NACL still blocks — demonstrates why defence in depth matters.

### Break 3: The NACL rule replaced

```bash
aws ec2 replace-network-acl-entry \
  --network-acl-id $NACL_ID \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=5432,To=5432 \
  --cidr-block 0.0.0.0/0 \
  --rule-action allow \
  --ingress
```

**What this does:** Replaces the existing NACL rule that allowed PostgreSQL from the app subnet CIDR (`10.0.10.0/24`) with a version that allows it from anywhere.

**Why it matters:** With this change, both the security group and the NACL on the data tier allow internet access. Now nothing but the routing table — no default route — prevents the database from being reached. And the routing table doesn't help for inbound connections, only outbound.

**The lesson:** This is the difference between "the security group was misconfigured" and "both controls failed." A single misconfiguration is recoverable. Two simultaneous failures are how real incidents happen.

---

## Detection Engineering

The audit script (`scripts/audit-vpc.sh`) checks three things:

1. **Security groups** for `0.0.0.0/0` on sensitive ports (22, 3389, 3306, 5432, 1433, 27017, 6379, 9200)
2. **NACLs** for overly permissive rules on the same ports
3. **VPC Flow Logs** enabled on every VPC

Findings are written to a timestamped JSON report. The script exits non-zero when findings exist, so CI/CD systems can fail the build.

### The core logic

```bash
sg_json=$(aws ec2 describe-security-groups --group-ids "$sg_id" --output json)

for port in "${SENSITIVE_PORTS[@]}"; do
  matches=$(echo "$sg_json" | jq --argjson port "$port" '
    [.SecurityGroups[0].IpPermissions[]
     | select(.FromPort <= $port and .ToPort >= $port)
     | .IpRanges[]
     | select(.CidrIp == "0.0.0.0/0")
    ] | length
  ')

  if [ "$matches" -gt 0 ] 2>/dev/null; then
    echo "  CRITICAL: port $port open to 0.0.0.0/0"
  fi
done
```

**Why `jq`, not JMESPath:** The initial version used `--query` with nested JMESPath filters. The pattern `SecurityGroups[0].IpPermissions[?FromPort<=\`22\`].IpRanges[?CidrIp=='0.0.0.0/0']` returned `[]` even when matching rules existed. Testing confirmed Floci's implementation of nested JMESPath filters was incomplete — one level of filtering worked, two didn't.

Switching to `--output json | jq` fixed it immediately. `jq` processes JSON structurally. It doesn't care about the source.

**Real-world takeaway:** `--query` is fine for simple field extraction. Anything beyond that — nested filters, conditional expressions, complex arrays — is more reliable with `jq`. This is a portability pattern, not just a Floci quirk.

### The NACL check — and its first false positive

The first version of the NACL check had a bug that the drill exposed. It flagged `public-nacl` for having ports 3389, 3306, 5432, 1433, 27017, 6379, and 9200 all "open to `0.0.0.0/0`."

But `public-nacl` doesn't open those ports. It opens the **ephemeral port range (1024–65535)** for return traffic. Every sensitive port above 1024 falls into that range, so the check flagged all of them.

**The fix:** Two classes of check.

- For ports **below 1024** (like SSH on 22): check whether the NACL rule *covers* the port (range query).
- For ports **1024 and above**: check whether the NACL rule is *exactly* that port (exact-match query).

```bash
if [ "$port" -ge 1024 ]; then
  # exact match only
  match=$(... | jq '... select(.PortRange.From == $port and .PortRange.To == $port) ...')
else
  # range check
  match=$(... | jq '... select(.PortRange.From <= $port and .PortRange.To >= $port) ...')
fi
```

**Why this matters:** It's a real detection-engineering lesson. A detector has to know what "normal" looks like. A wide ephemeral range is required by NACL semantics; it's not a finding. A specific service port open to the internet is. The two look similar in the raw data but mean different things.

> **Interview-grade insight:** "I learned to model the correct baseline before writing the detection. If the detector doesn't know what 'safe' looks like, everything looks suspicious, and the signal gets lost in the noise."

---

## Remediation

Two paths were demonstrated, and both matter in real incident response.

### Path A: CLI — immediate containment

```bash
aws ec2 revoke-security-group-ingress \
  --group-id sg-9d724360e71bc3b40 \
  --protocol tcp \
  --port 22 \
  --cidr 0.0.0.0/0

aws ec2 revoke-security-group-ingress \
  --group-id sg-2d32eb3364902f43e \
  --protocol tcp \
  --port 5432 \
  --cidr 0.0.0.0/0

aws ec2 replace-network-acl-entry \
  --network-acl-id $NACL_ID \
  --rule-number 100 \
  --protocol tcp \
  --port-range From=5432,To=5432 \
  --cidr-block 10.0.10.0/24 \
  --rule-action allow \
  --ingress
```

**When to use:** Active incident. Every second of exposure matters. CLI is immediate.

**What it doesn't do:** Reconcile Terraform state. Terraform still thinks the wrong rules exist. This matters if a subsequent `terraform apply` runs — it might try to re-apply something you didn't intend, or produce a confusing drift report.

### Path B: Terraform — declarative reconciliation

```bash
cd phase-4-vpc-security
terraform apply
```

**What this does:** Restores the environment to exactly what the config declares. Also fixes the smaller drifts the CLI fix missed — in this case, a tag on the Flow Log resource that had fallen out of sync.

**When to use:** After containing the immediate issue. This is the "make reality match config" step.

**Why both:** In a real incident, you don't choose. You do both. Fast containment via CLI. Then reconciliation via Terraform. Then verify with `terraform plan` returning "No changes" and the audit returning 0 findings. Only when both agree do you have high confidence the environment is correct.

---

## Verification

After both remediation paths:

- **Audit script:** 0 findings across all security groups, NACLs, and VPCs.
- **Terraform plan:** "No changes. Your infrastructure matches the configuration."
- **Full cycle confirmation:** Break → detect → contain → reconcile → verify all returned to baseline.

Both tools agree. That's the confidence signal.

---

## Key Lessons

### Lesson 1: Defence in depth means independent controls

The data tier had three independent protections:

1. **Routing** — no default route to the internet
2. **NACL** — only the app subnet CIDR can reach it
3. **Security group** — only the app SG can reach it, no egress

Any single one failing should not result in exposure. The misconfiguration drill proved this: even after breaking the SG and the NACL simultaneously, the absence of a route still meant the database couldn't reach the internet. The path to compromise required all three to fail.

### Lesson 2: JMESPath and jq are not interchangeable

Nested JMESPath filters via `--query` behaved inconsistently against Floci. `jq` did not. The portability rule:

- **Simple field extraction** — `--query` is fine
- **Nested filters, conditional logic, complex structures** — `jq`

This isn't a Floci quirk. It's a portability pattern that applies against real AWS too, where service-specific query implementations differ subtly. `jq` is deterministic.

### Lesson 3: Detection tooling needs its own testing

The NACL check's false positive on ephemeral ports was found *only* because the misconfiguration drill forced the script to run against a broken environment. Testing against a clean baseline would never have exposed it.

Two rules follow:

1. Test detection against a known-bad case, not just a clean one.
2. Understand what "normal" looks like for the thing you're detecting — otherwise you flag everything.

### Lesson 4: Stateless vs stateful — the ephemeral port trap

NACLs are **stateless**. Security groups are **stateful**. Concretely:

- **SG:** Allow port 443 inbound. Return traffic is automatic.
- **NACL:** Allow port 443 inbound. Return traffic needs *its own rule* — a rule for the ephemeral port range (typically 1024–65535) inbound.

Every NACL that allows outbound connections needs matching inbound ephemeral rules. Forgetting this is why NACLs "sometimes work and sometimes don't" — the connection establishes but the response gets dropped.

### Lesson 5: The routing table is the strongest control

A route is a deliberate act. A security group rule is often a matter of changing a number. A NACL rule is often inherited from a template. But a route — you have to *add* it. It's hard to add by accident.

This makes the routing table the most reliable layer of defence. Build the network so that the default state is "no path" — then add paths only where they're needed.

### Lesson 6: CLI fixes reality; Terraform fixes state

Both are necessary. Neither alone is enough in an environment managed by IaC.

- CLI fixes the running system but leaves Terraform out of sync.
- Terraform reconciles its declared state to reality but may act unpredictably if reality was changed by other means.

The correct sequence is: **CLI to contain, Terraform to reconcile, audit and plan to verify.** Only when both the CLI audit and `terraform plan` agree that everything is correct do you have confidence.

---

## What I'd Do Differently

**1. Test the audit script against the broken state first.** I built it against the clean baseline and only discovered the ephemeral-port false positive when I deliberately broke a NACL. In a real security team, detection content is developed against known-bad samples before deployment, for exactly this reason.

**2. Use `jq` from the start.** The first version of the script mixed `--query` and `jq`. Once the pattern "always use `--output json | jq`" was applied, the script became shorter, more reliable, and easier to reason about.

**3. Add the NACL for the app subnet.** The app subnet currently uses the VPC's default NACL, which allows all traffic. That's the AWS default and not wrong, but for full defence-in-depth parity with the other tiers, an app-subnet NACL would restrict ingress to the public subnet's CIDR and egress to the data subnet. The security groups already provide this control, so it's an additional layer rather than a gap.

**4. Add VPC endpoints for AWS services.** In a real environment, the app tier's traffic to S3 or DynamoDB would go via NAT, costing money and adding a hop. VPC endpoints let you reach AWS services without going through the internet. That's both a cost optimisation and a security improvement — traffic stays inside AWS's network.

**5. Test the tag-drift scenario in advance.** The Flow Log tag going out of sync was minor but educational — it's exactly what Terraform drift detection is for. Documenting tag management as a distinct concern would have prepared me for it.

---

## Outcome

After building and drilling the environment:

- **Three-tier VPC** with public, private-app, and private-data subnets
- **Routing controls** — IGW for public, NAT for private-app, no route for private-data
- **Three security groups** — tier-scoped, identity-based tier-to-tier access, no egress on data tier
- **Two network ACLs** — public (permissive egress, specific ingress) and data (app-subnet CIDR only)
- **VPC Flow Logs** capturing ALL traffic to S3, with Block Public Access enabled
- **A custom audit script** covering security groups, NACLs, and flow logs, with JSON reporting and CI-friendly exit codes
- **A misconfiguration drill** demonstrating end-to-end detection and remediation
- **Two remediation paths** — CLI for containment, Terraform for reconciliation
- **All infrastructure under version control** with remote state

The project demonstrates the network security lifecycle that cloud security engineering relies on: **design the controls, build the baseline, test detection against known-bad cases, and prove remediation works.**

The most valuable lesson wasn't about any single AWS service. It was that **detection is software**, and software has bugs. The false positive on ephemeral ports would have produced weeks of noise in a production environment. The nested JMESPath failure would have produced *silent* false negatives — the worst kind. Both bugs were found by running the detector against a deliberately broken environment, not by reading the code.

That's the discipline this project exists to demonstrate.

---

## Repository

The full project is in the `phase-4-vpc-security/` folder of the `aws-storage-platform` repository. Terraform configuration, audit script, and this case study are all version-controlled.

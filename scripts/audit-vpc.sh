#!/bin/bash
# audit-vpc.sh — VPC network security audit
# Checks:
#   1. Security groups for 0.0.0.0/0 on sensitive ports
#   2. NACLs for overly permissive rules
#   3. VPC Flow Logs enabled

REPORT_DIR="$(cd "$(dirname "$0")/../reports" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
REPORT_FILE="${REPORT_DIR}/audit-vpc-${TIMESTAMP}.json"

mkdir -p "$REPORT_DIR"

echo "=== VPC Network Security Audit ==="
echo "Started: $TIMESTAMP"
echo

SENSITIVE_PORTS=(22 3389 3306 5432 1433 27017 6379 9200)

findings_json="[]"
total_findings=0

# ============================================================
# Check 1: Security groups
# ============================================================
echo "--- Security Groups ---"
sgs=$(aws ec2 describe-security-groups --output json | jq -r '.SecurityGroups[] | [.GroupId, .GroupName] | @tsv' | tr -d '\r')

while IFS=$'\t' read -r sg_id sg_name; do
  sg_name="${sg_name%$'\r'}"
  [ -z "$sg_id" ] && continue
  echo "Checking: $sg_name ($sg_id)"
  sg_findings=()

  # Fetch all ingress permissions once, then filter with jq per port
  sg_json=$(aws ec2 describe-security-groups --group-ids "$sg_id" --output json 2>/dev/null | tr -d '\r')

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
      sg_findings+=("port_${port}_open_to_internet")
    fi
  done

  if [ ${#sg_findings[@]} -gt 0 ]; then
    total_findings=$((total_findings + ${#sg_findings[@]}))
    findings_list=$(printf '%s\n' "${sg_findings[@]}" | jq -R . | jq -s .)
    findings_json=$(echo "$findings_json" | jq \
      --arg sg "$sg_name" \
      --argjson findings "$findings_list" \
      '. + [{"type": "security_group", "name": $sg, "findings": $findings}]')
  fi
done <<< "$sgs"

# ============================================================
# Check 2: NACLs
# ============================================================
echo
echo "--- Network ACLs ---"
nacls=$(aws ec2 describe-network-acls --output json | jq -r '.NetworkAcls[].NetworkAclId' | tr -d '\r')

while read -r nacl_id; do
  nacl_id="${nacl_id%$'\r'}"
  [ -z "$nacl_id" ] && continue
  echo "Checking: $nacl_id"
  nacl_findings=()

  nacl_json=$(aws ec2 describe-network-acls --network-acl-ids "$nacl_id" --output json 2>/dev/null | tr -d '\r')

  for port in "${SENSITIVE_PORTS[@]}"; do
    # Ports in the ephemeral range (1024-65535) appear "open" to 0.0.0.0/0
    # on any NACL that allows ephemeral return traffic. That's required,
    # not a finding. Only flag exact-port matches for those.
    if [ "$port" -ge 1024 ]; then
      match=$(echo "$nacl_json" | jq --argjson port "$port" '
        [.NetworkAcls[0].Entries[]
         | select(.Egress == false)
         | select(.RuleAction == "allow")
         | select(.CidrBlock == "0.0.0.0/0")
         | select(.PortRange.From == $port and .PortRange.To == $port)
        ] | length
      ')
    else
      match=$(echo "$nacl_json" | jq --argjson port "$port" '
        [.NetworkAcls[0].Entries[]
         | select(.Egress == false)
         | select(.RuleAction == "allow")
         | select(.CidrBlock == "0.0.0.0/0")
         | select(.PortRange.From <= $port and .PortRange.To >= $port)
        ] | length
      ')
    fi

    if [ "$match" -gt 0 ] 2>/dev/null; then
      echo "  CRITICAL: port $port open to 0.0.0.0/0"
      nacl_findings+=("nacl_port_${port}_open_to_internet")
    fi
  done

  if [ ${#nacl_findings[@]} -gt 0 ]; then
    total_findings=$((total_findings + ${#nacl_findings[@]}))
    findings_list=$(printf '%s\n' "${nacl_findings[@]}" | jq -R . | jq -s .)
    findings_json=$(echo "$findings_json" | jq \
      --arg nacl "$nacl_id" \
      --argjson findings "$findings_list" \
      '. + [{"type": "network_acl", "name": $nacl, "findings": $findings}]')
  fi
done <<< "$nacls"

# ============================================================
# Check 3: Flow Logs
# ============================================================
echo
echo "--- VPC Flow Logs ---"
vpcs=$(aws ec2 describe-vpcs --output json | jq -r '.Vpcs[].VpcId' | tr -d '\r')

for vpc_id in $vpcs; do
  [ -z "$vpc_id" ] && continue
  echo "Checking: $vpc_id"

  flow_logs=$(aws ec2 describe-flow-logs \
    --filter "Name=resource-id,Values=$vpc_id" \
    --output json 2>/dev/null | jq '.FlowLogs | length' | tr -d '\r')

  if [ "$flow_logs" = "0" ] || [ -z "$flow_logs" ]; then
    echo "  WARN: no flow logs enabled"
    total_findings=$((total_findings + 1))
    findings_json=$(echo "$findings_json" | jq \
      --arg vpc "$vpc_id" \
      '. + [{"type": "vpc", "name": $vpc, "findings": ["no_flow_logs_enabled"]}]')
  fi
done

echo
echo "=== Audit complete ==="
echo "Total findings: $total_findings"

cat > "$REPORT_FILE" <<EOF
{
  "timestamp": "$TIMESTAMP",
  "total_findings": $total_findings,
  "results": $findings_json
}
EOF

echo "Report written: $REPORT_FILE"

if [ "$total_findings" -gt 0 ]; then
  exit 1
fi
exit 0
#!/bin/bash
# audit-s3.sh — S3 security audit
# Checks every bucket for:
#   1. Block Public Access enabled (all four settings)
#   2. Bucket policies with Allow + wildcard Principal

REPORT_DIR="$(cd "$(dirname "$0")/../reports" && pwd)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H-%M-%SZ")
REPORT_FILE="${REPORT_DIR}/audit-${TIMESTAMP}.json"

mkdir -p "$REPORT_DIR"

echo "=== S3 Security Audit ==="
echo "Started: $TIMESTAMP"
echo

buckets=$(aws s3 ls | awk '{print $3}')

if [ -z "$buckets" ]; then
  echo "No buckets found."
  exit 0
fi

findings_json="[]"
total_findings=0

for bucket in $buckets; do
  echo "--- $bucket ---"
  bucket_findings=()

  # --- Check 1: Block Public Access ---
  pab=$(aws s3api get-public-access-block --bucket "$bucket" --output json 2>/dev/null)

  if [ -z "$pab" ]; then
    echo "  WARN: No Block Public Access configuration"
    bucket_findings+=("no_public_access_block_configured")
  else
    for setting in BlockPublicAcls BlockPublicPolicy IgnorePublicAcls RestrictPublicBuckets; do
      value=$(echo "$pab" | jq -r ".PublicAccessBlockConfiguration.${setting}")
      if [ "$value" = "false" ]; then
        echo "  WARN: ${setting} is false"
        bucket_findings+=("${setting}_disabled")
      fi
    done
  fi

  # --- Check 2: Bucket policy with Allow + wildcard principal ---
  policy_raw=$(aws s3api get-bucket-policy --bucket "$bucket" --query Policy --output text 2>/dev/null)

  if [ -n "$policy_raw" ] && [ "$policy_raw" != "None" ]; then
    has_wildcard=$(echo "$policy_raw" | jq '
      [.Statement[] | select(.Effect == "Allow") | select(.Principal == "*")] | length
    ' 2>/dev/null)

    if [ -n "$has_wildcard" ] && [ "$has_wildcard" -gt 0 ] 2>/dev/null; then
      echo "  CRITICAL: Public policy with wildcard principal (Allow)"
      bucket_findings+=("public_policy_wildcard_allow")
    fi
  fi

  # --- Record findings for this bucket ---
  if [ ${#bucket_findings[@]} -gt 0 ]; then
    count=${#bucket_findings[@]}
    total_findings=$((total_findings + count))

    findings_list=$(printf '%s\n' "${bucket_findings[@]}" | jq -R . | jq -s .)

    findings_json=$(echo "$findings_json" | jq \
      --arg bucket "$bucket" \
      --argjson findings "$findings_list" \
      '. + [{"bucket": $bucket, "findings": $findings}]')
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
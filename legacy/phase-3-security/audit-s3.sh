#!/bin/bash
# audit-s3.sh — S3 security audit
# Checks every bucket for:
#   1. Block Public Access enabled (all four settings)
#   2. Bucket policies with wildcard principals

echo "=== S3 Security Audit ==="
echo

# Collect all bucket names
buckets=$(aws s3 ls | awk '{print $3}')

if [ -z "$buckets" ]; then
  echo "No buckets found."
  exit 0
fi

findings=0

for bucket in $buckets; do
  echo "--- $bucket ---"

  # Check Block Public Access
  pab=$(aws s3api get-public-access-block --bucket "$bucket" 2>/dev/null)
  if [ -z "$pab" ]; then
    echo "  ⚠️  No Block Public Access configuration"
    findings=$((findings+1))
  else
    if echo "$pab" | grep -q '"BlockPublicAcls": false'; then
      echo "  ⚠️  BlockPublicAcls is false"
      findings=$((findings+1))
    fi
    if echo "$pab" | grep -q '"BlockPublicPolicy": false'; then
      echo "  ⚠️  BlockPublicPolicy is false"
      findings=$((findings+1))
    fi
    if echo "$pab" | grep -q '"IgnorePublicAcls": false'; then
      echo "  ⚠️  IgnorePublicAcls is false"
      findings=$((findings+1))
    fi
    if echo "$pab" | grep -q '"RestrictPublicBuckets": false'; then
      echo "  ⚠️  RestrictPublicBuckets is false"
      findings=$((findings+1))
    fi
  fi

  # Check bucket policy for wildcard principals
  policy=$(aws s3api get-bucket-policy --bucket "$bucket" 2>/dev/null)
  if [ -n "$policy" ]; then
    if echo "$policy" | grep -q '\\"Principal\\":\\"\\*\\"'; then
      echo "  🚨 PUBLIC POLICY with wildcard principal"
      findings=$((findings+1))
    fi
  fi
done

echo
echo "=== Audit complete ==="
echo "Findings: $findings"
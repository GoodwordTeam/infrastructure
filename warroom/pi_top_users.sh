#!/bin/bash

# -------------------------------
# SET THESE VARIABLES
# -------------------------------
RESOURCE_ID="db-JMQMG2WVIWZD4CNDNGV2RR5F5M"
REGION="us-east-2"

# -------------------------------
# TIME RANGE: last 4 hours
# -------------------------------
START_TIME=$(date -u -v -4H +"%Y-%m-%dT%H:%M:%SZ")
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# -------------------------------
# Get dimension keys (digests)
# -------------------------------
aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$RESOURCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --metric db.load.avg \
  --group-by Group=db.user \
  --region "$REGION" \
  --output json > pi_keys.json

# -------------------------------
# Print basic summary
# -------------------------------
echo "=== Top DB Users by Load (Last 4 hours) ==="
cat pi_keys.json | jq -r '.Keys[] | "\(.Dimensions."db.user.name") | Total Load: \(.Total)"'

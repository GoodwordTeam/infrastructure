#!/bin/bash

# -------------------------------
# CONFIG
# -------------------------------
RESOURCE_ID="db-JMQMG2WVIWZD4CNDNGV2RR5F5M"
REGION="us-east-2"

# -------------------------------
# TIME RANGE: last 4 hours
# -------------------------------
START_TIME=$(date -u -v -4H +"%Y-%m-%dT%H:%M:%SZ")
END_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

echo ""
echo "==============================="
echo "AWS Performance Insights Report"
echo "Cluster: $RESOURCE_ID"
echo "Region:  $REGION"
echo "Range:   $START_TIME to $END_TIME"
echo "==============================="
echo ""

# -------------------------------
# TOP DB USERS
# -------------------------------
aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$RESOURCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --metric db.load.avg \
  --group-by Group=db.user \
  --region "$REGION" \
  --output json > pi_users.json

echo "=== Top DB Users ==="
if jq -e '.Keys | length > 0' pi_users.json > /dev/null; then
  jq -r '.Keys[] | "\(.Dimensions."db.user.name") | Total Load: \(.Total)"' pi_users.json
else
  echo "No user data available."
fi
echo ""

# -------------------------------
# TOP WAIT EVENTS
# -------------------------------
aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$RESOURCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --metric db.load.avg \
  --group-by Group=db.wait_event \
  --region "$REGION" \
  --output json > pi_waits.json

echo "=== Top Wait Events ==="
if jq -e '.Keys | length > 0' pi_waits.json > /dev/null; then
  jq -r '.Keys[] | "\(.Dimensions."db.wait_event") | Total Load: \(.Total)"' pi_waits.json
else
  echo "No wait event data available."
fi
echo ""

# -------------------------------
# TOP HOSTS
# -------------------------------
aws pi describe-dimension-keys \
  --service-type RDS \
  --identifier "$RESOURCE_ID" \
  --start-time "$START_TIME" \
  --end-time "$END_TIME" \
  --metric db.load.avg \
  --group-by Group=db.host \
  --region "$REGION" \
  --output json > pi_hosts.json

echo "=== Top Hosts ==="
if jq -e '.Keys | length > 0' pi_hosts.json > /dev/null; then
  jq -r '.Keys[] | "\(.Dimensions."db.host") | Total Load: \(.Total)"' pi_hosts.json
else
  echo "No host data available."
fi
echo ""

echo "✅ Report Complete!"
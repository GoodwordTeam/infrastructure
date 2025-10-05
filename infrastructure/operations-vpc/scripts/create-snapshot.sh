#!/bin/bash
# Create RDS snapshot before infrastructure changes

set -e

DB_INSTANCE_ID="ops-sqlmesh-postgres"
SNAPSHOT_ID="ops-sqlmesh-postgres-$(date +%Y%m%d-%H%M%S)"

echo "Creating snapshot: $SNAPSHOT_ID"

aws rds create-db-snapshot \
    --region us-east-2 \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-snapshot-identifier "$SNAPSHOT_ID"

echo "Snapshot creation initiated: $SNAPSHOT_ID"
echo "Check status with: aws rds describe-db-snapshots --db-snapshot-identifier $SNAPSHOT_ID"


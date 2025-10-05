#!/bin/bash
# Backup PostgreSQL database before destroy/redeploy

set -e

# Configuration
DB_HOST="ops-sqlmesh-postgres.cbys2uie40p0.us-east-2.rds.amazonaws.com"
DB_NAME="sqlmesh"
DB_USER="postgres"
BACKUP_DIR="/tmp/sqlmesh-backup-$(date +%Y%m%d-%H%M%S)"
S3_BUCKET="ops-vpc-backups"  # You'll need to create this

echo "Creating backup directory: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Get database password from Secrets Manager
echo "Getting database password from Secrets Manager..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "ops-vpc/postgresql/password" \
    --region us-east-2 \
    --query SecretString --output text)

# Create database dump
echo "Creating database dump..."
PGPASSWORD="$DB_PASSWORD" pg_dump \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    --verbose \
    --no-password \
    > "$BACKUP_DIR/sqlmesh-database.sql"

# Create SQLMesh configuration backup
echo "Backing up SQLMesh configuration..."
# This would need to be run on the SQLMesh Server
# scp ec2-user@172.22.2.106:/home/ec2-user/sqlmesh/config.yaml "$BACKUP_DIR/"
# scp -r ec2-user@172.22.2.106:/home/ec2-user/sqlmesh/models "$BACKUP_DIR/"

# Upload to S3
echo "Uploading backup to S3..."
aws s3 cp "$BACKUP_DIR/sqlmesh-database.sql" "s3://$S3_BUCKET/sqlmesh-backup-$(date +%Y%m%d-%H%M%S).sql"

echo "Backup completed: $BACKUP_DIR"
echo "S3 location: s3://$S3_BUCKET/sqlmesh-backup-$(date +%Y%m%d-%H%M%S).sql"


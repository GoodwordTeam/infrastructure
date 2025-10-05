#!/bin/bash
# Restore PostgreSQL database after redeploy

set -e

# Configuration
DB_HOST="${DB_HOST:-ops-sqlmesh-postgres.cbys2uie40p0.us-east-2.rds.amazonaws.com}"
DB_NAME="sqlmesh"
DB_USER="postgres"
BACKUP_FILE="${1:-/tmp/sqlmesh-backup-latest.sql}"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    echo "Usage: $0 [backup-file-path]"
    exit 1
fi

echo "Restoring database from: $BACKUP_FILE"

# Get database password from Secrets Manager
echo "Getting database password from Secrets Manager..."
DB_PASSWORD=$(aws secretsmanager get-secret-value \
    --secret-id "ops-vpc/postgresql/password" \
    --region us-east-2 \
    --query SecretString --output text)

# Wait for database to be available
echo "Waiting for database to be available..."
until PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d postgres -c '\q' 2>/dev/null; do
    echo "Database not ready, waiting..."
    sleep 10
done

# Restore database
echo "Restoring database..."
PGPASSWORD="$DB_PASSWORD" psql \
    -h "$DB_HOST" \
    -U "$DB_USER" \
    -d "$DB_NAME" \
    -f "$BACKUP_FILE"

echo "Database restore completed!"


#!/bin/bash

# Deploy SQLMesh Docker Container
# This script deploys the SQLMesh Docker container with the working configuration

set -e

# Configuration
INSTANCE_ID="i-03519bd309babd741"
REGION="us-east-2"
STACK_NAME="ops-vpc"

echo "🐳 Deploying SQLMesh Docker Container..."

# Get database credentials from AWS Secrets Manager
echo "📋 Retrieving database credentials..."
DB_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "postgres-operations-db" --region "$REGION" --query 'SecretString' --output text | jq -r '.password')
SNOWFLAKE_PASSWORD=$(aws secretsmanager get-secret-value --secret-id "snowflake-warehouse" --region "$REGION" --query 'SecretString' --output text | jq -r '.password')

# Create config.yaml with actual credentials
echo "📝 Creating SQLMesh configuration..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cat > /opt/sqlmesh/config.yaml << 'EOF'
default_environment: dev
environments:
  - name: dev
    default: true
  - name: prod

gateways:
  snowflake:
    type: snowflake
    account: vsc91540.us-east-1
    user: CHRIS
    password: $SNOWFLAKE_PASSWORD
    warehouse: COMPUTE_WH
    database: AIRBYTE_DB
    schema: RAW

  postgres:
    type: postgres
    host: 172.22.2.106
    port: 5432
    user: postgres
    password: $DB_PASSWORD
    database: sqlmesh_data

storage:
  type: s3
  bucket: ops-sqlmesh-artifacts-058264125918
  prefix: sqlmesh
EOF\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/config_cmd.txt

echo "⏳ Waiting for configuration to be created..."
aws ssm wait command-executed --command-id $(cat /tmp/config_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Deploy Docker Compose
echo "🚀 Deploying Docker Compose..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cd /opt/sqlmesh && docker-compose down && docker-compose up -d\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/docker_cmd.txt

echo "⏳ Waiting for Docker deployment..."
aws ssm wait command-executed --command-id $(cat /tmp/docker_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Check status
echo "🔍 Checking SQLMesh status..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"docker ps | grep sqlmesh\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/status_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/status_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"
aws ssm get-command-invocation --command-id $(cat /tmp/status_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION" --query 'StandardOutputContent' --output text

echo "✅ SQLMesh Docker deployment complete!"
echo "🌐 Access at: https://sqlmesh.internal.goodword.cloud"

# Cleanup
rm -f /tmp/config_cmd.txt /tmp/docker_cmd.txt /tmp/status_cmd.txt

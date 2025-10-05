#!/bin/bash

# Update SQLMesh Server with correct Docker image
# This script updates the running SQLMesh Server to use tobikodata/tcloud:2.5.0

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get SQLMesh Server instance ID
log_info "Getting SQLMesh Server instance ID..."
SQLMESH_INSTANCE_ID=$(aws cloudformation describe-stacks \
    --stack-name ops-vpc-sqlmesh-server \
    --region us-east-2 \
    --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshServerInstanceId`].OutputValue' \
    --output text)

if [ -z "$SQLMESH_INSTANCE_ID" ] || [ "$SQLMESH_INSTANCE_ID" = "None" ]; then
    log_error "Failed to get SQLMesh Server instance ID"
    exit 1
fi

log_info "SQLMesh Server Instance ID: $SQLMESH_INSTANCE_ID"

# Update docker-compose.yml with correct image
log_info "Updating docker-compose.yml with tobikodata/tcloud:2.5.0..."
aws ssm send-command \
    --instance-ids "$SQLMESH_INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "cd /home/ec2-user/sqlmesh",
        "sed -i \"s/tobik\/sqlmesh:latest/tobikodata\/tcloud:2.5.0/g\" docker-compose.yml",
        "cat docker-compose.yml"
    ]' \
    --region us-east-2 \
    --query 'Command.CommandId' \
    --output text > /tmp/update_compose_cmd.txt

COMMAND_ID=$(cat /tmp/update_compose_cmd.txt)
log_info "Command ID: $COMMAND_ID"

# Wait for command to complete
log_info "Waiting for docker-compose.yml update to complete..."
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2

# Check command status
STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2 \
    --query 'Status' \
    --output text)

if [ "$STATUS" != "Success" ]; then
    log_error "Failed to update docker-compose.yml"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$SQLMESH_INSTANCE_ID" \
        --region us-east-2 \
        --query 'StandardErrorContent' \
        --output text
    exit 1
fi

log_info "docker-compose.yml updated successfully"

# Pull the correct Docker image
log_info "Pulling tobikodata/tcloud:2.5.0 image..."
aws ssm send-command \
    --instance-ids "$SQLMESH_INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "docker pull tobikodata/tcloud:2.5.0"
    ]' \
    --region us-east-2 \
    --query 'Command.CommandId' \
    --output text > /tmp/pull_image_cmd.txt

COMMAND_ID=$(cat /tmp/pull_image_cmd.txt)
log_info "Command ID: $COMMAND_ID"

# Wait for image pull to complete
log_info "Waiting for Docker image pull to complete..."
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2

# Check command status
STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2 \
    --query 'Status' \
    --output text)

if [ "$STATUS" != "Success" ]; then
    log_error "Failed to pull Docker image"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$SQLMESH_INSTANCE_ID" \
        --region us-east-2 \
        --query 'StandardErrorContent' \
        --output text
    exit 1
fi

log_info "Docker image pulled successfully"

# Restart SQLMesh service
log_info "Restarting SQLMesh service..."
aws ssm send-command \
    --instance-ids "$SQLMESH_INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters 'commands=[
        "cd /home/ec2-user/sqlmesh",
        "docker-compose down",
        "docker-compose up -d",
        "sleep 10",
        "docker ps"
    ]' \
    --region us-east-2 \
    --query 'Command.CommandId' \
    --output text > /tmp/restart_sqlmesh_cmd.txt

COMMAND_ID=$(cat /tmp/restart_sqlmesh_cmd.txt)
log_info "Command ID: $COMMAND_ID"

# Wait for restart to complete
log_info "Waiting for SQLMesh restart to complete..."
aws ssm wait command-executed \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2

# Check command status
STATUS=$(aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2 \
    --query 'Status' \
    --output text)

if [ "$STATUS" != "Success" ]; then
    log_error "Failed to restart SQLMesh service"
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$SQLMESH_INSTANCE_ID" \
        --region us-east-2 \
        --query 'StandardErrorContent' \
        --output text
    exit 1
fi

log_info "SQLMesh service restarted successfully"

# Show container status
log_info "Current container status:"
aws ssm get-command-invocation \
    --command-id "$COMMAND_ID" \
    --instance-id "$SQLMESH_INSTANCE_ID" \
    --region us-east-2 \
    --query 'StandardOutputContent' \
    --output text

# Get SQLMesh Server private IP for testing
SQLMESH_PRIVATE_IP=$(aws ec2 describe-instances \
    --instance-ids "$SQLMESH_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text)

log_info "SQLMesh Server Private IP: $SQLMESH_PRIVATE_IP"
log_info "SQLMesh UI should be available at: http://$SQLMESH_PRIVATE_IP:8000"

# Clean up temp files
rm -f /tmp/update_compose_cmd.txt /tmp/pull_image_cmd.txt /tmp/restart_sqlmesh_cmd.txt

log_info "SQLMesh Docker image update completed successfully!"

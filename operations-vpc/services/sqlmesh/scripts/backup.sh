#!/bin/bash

# Backup SQLMesh Configuration
# This script backs up the complete SQLMesh configuration from the running server

set -e

# Configuration
INSTANCE_ID="i-03519bd309babd741"
REGION="us-east-2"
BACKUP_DIR="./sqlmesh-backup-$(date +%Y%m%d-%H%M%S)"

echo "📦 Backing up SQLMesh configuration..."

# Create backup directory
mkdir -p "$BACKUP_DIR"

# Backup configuration file
echo "📋 Backing up config.yaml..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cat /home/ec2-user/sqlmesh/config.yaml\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/backup_config_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/backup_config_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"
aws ssm get-command-invocation --command-id $(cat /tmp/backup_config_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION" --query 'StandardOutputContent' --output text > "$BACKUP_DIR/config.yaml"

# Backup Docker Compose
echo "🐳 Backing up docker-compose.yml..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cat /home/ec2-user/sqlmesh/docker-compose.yml\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/backup_compose_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/backup_compose_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"
aws ssm get-command-invocation --command-id $(cat /tmp/backup_compose_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION" --query 'StandardOutputContent' --output text > "$BACKUP_DIR/docker-compose.yml"

# Backup models directory
echo "📊 Backing up models..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cd /home/ec2-user/sqlmesh && tar -czf /tmp/models.tar.gz models/\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/backup_models_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/backup_models_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Download models backup
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"base64 -w 0 /tmp/models.tar.gz\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/backup_models_download_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/backup_models_download_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"
aws ssm get-command-invocation --command-id $(cat /tmp/backup_models_download_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION" --query 'StandardOutputContent' --output text | base64 -d > "$BACKUP_DIR/models.tar.gz"

# Backup tests directory
echo "🧪 Backing up tests..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cd /home/ec2-user/sqlmesh && tar -czf /tmp/tests.tar.gz tests/\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/backup_tests_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/backup_tests_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Download tests backup
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"base64 -w 0 /tmp/tests.tar.gz\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/backup_tests_download_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/backup_tests_download_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"
aws ssm get-command-invocation --command-id $(cat /tmp/backup_tests_download_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION" --query 'StandardOutputContent' --output text | base64 -d > "$BACKUP_DIR/tests.tar.gz"

# Create deployment script
echo "📝 Creating deployment script..."
cat > "$BACKUP_DIR/deploy-sqlmesh.sh" << 'EOF'
#!/bin/bash

# Deploy SQLMesh from backup
set -e

INSTANCE_ID="i-03519bd309babd741"
REGION="us-east-2"

echo "🚀 Deploying SQLMesh from backup..."

# Create directory structure
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"mkdir -p /home/ec2-user/sqlmesh/{models,tests}\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/create_dirs_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/create_dirs_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Deploy configuration files
echo "📋 Deploying configuration..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cat > /home/ec2-user/sqlmesh/config.yaml << 'CONFIG_EOF'
$(cat config.yaml)
CONFIG_EOF\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/deploy_config_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/deploy_config_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Deploy Docker Compose
echo "🐳 Deploying Docker Compose..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cat > /home/ec2-user/sqlmesh/docker-compose.yml << 'COMPOSE_EOF'
$(cat docker-compose.yml)
COMPOSE_EOF\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/deploy_compose_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/deploy_compose_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Deploy models
echo "📊 Deploying models..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"base64 -d > /tmp/models.tar.gz << 'MODELS_EOF'
$(base64 -w 0 models.tar.gz)
MODELS_EOF
cd /home/ec2-user/sqlmesh && tar -xzf /tmp/models.tar.gz\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/deploy_models_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/deploy_models_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Deploy tests
echo "🧪 Deploying tests..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"base64 -d > /tmp/tests.tar.gz << 'TESTS_EOF'
$(base64 -w 0 tests.tar.gz)
TESTS_EOF
cd /home/ec2-user/sqlmesh && tar -xzf /tmp/tests.tar.gz\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/deploy_tests_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/deploy_tests_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

# Deploy and start SQLMesh
echo "🚀 Starting SQLMesh..."
aws ssm send-command \
    --instance-ids "$INSTANCE_ID" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"cd /home/ec2-user/sqlmesh && docker-compose down && docker-compose up -d\"]" \
    --region "$REGION" \
    --query 'Command.CommandId' \
    --output text > /tmp/start_sqlmesh_cmd.txt

aws ssm wait command-executed --command-id $(cat /tmp/start_sqlmesh_cmd.txt) --instance-id "$INSTANCE_ID" --region "$REGION"

echo "✅ SQLMesh deployment complete!"
echo "🌐 Access at: https://sqlmesh.internal.goodword.cloud"

# Cleanup
rm -f /tmp/*_cmd.txt
EOF

chmod +x "$BACKUP_DIR/deploy-sqlmesh.sh"

echo "✅ Backup complete!"
echo "📁 Backup directory: $BACKUP_DIR"
echo "🚀 To redeploy: cd $BACKUP_DIR && ./deploy-sqlmesh.sh"

# Cleanup
rm -f /tmp/*_cmd.txt

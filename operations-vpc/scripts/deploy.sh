#!/bin/bash

# Operations VPC Deployment Script - Layered Approach
# This script deploys the Operations VPC infrastructure using CloudFormation

set -e

# Configuration
STACK_PREFIX="ops-vpc"
REGION="us-east-2"
TEMPLATE_DIR="./"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] ✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] ⚠${NC} $1"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ✗${NC} $1"
}

# Function to check if AWS CLI is configured
check_aws_cli() {
    log "Checking AWS CLI configuration..."
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        log_error "AWS CLI is not configured or credentials are invalid"
        log "Please run: aws configure or aws sso login"
        exit 1
    fi
    log_success "AWS CLI is configured"
}

# Function to retrieve secrets from AWS Secrets Manager
get_secrets_from_aws() {
    log "Retrieving secrets from AWS Secrets Manager..."
    
    # Get SQLMesh PostgreSQL credentials
    SQLMESH_POSTGRES_SECRET=$(aws secretsmanager get-secret-value --secret-id "aurora-data-operations" --region us-east-2 --query 'SecretString' --output text)
    SQLMESH_POSTGRES_HOST=$(echo "$SQLMESH_POSTGRES_SECRET" | jq -r '.host')
    SQLMESH_POSTGRES_PORT=$(echo "$SQLMESH_POSTGRES_SECRET" | jq -r '.port')
    SQLMESH_POSTGRES_USER=$(echo "$SQLMESH_POSTGRES_SECRET" | jq -r '.username')
    SQLMESH_POSTGRES_PASSWORD=$(echo "$SQLMESH_POSTGRES_SECRET" | jq -r '.password')
    
    # Get Snowflake credentials
    SNOWFLAKE_SECRET=$(aws secretsmanager get-secret-value --secret-id "snowflake-warehouse" --region us-east-2 --query 'SecretString' --output text)
    SNOWFLAKE_ACCOUNT=$(echo "$SNOWFLAKE_SECRET" | jq -r '.account')
    SNOWFLAKE_USER=$(echo "$SNOWFLAKE_SECRET" | jq -r '.user')
    SNOWFLAKE_PASSWORD=$(echo "$SNOWFLAKE_SECRET" | jq -r '.password')
    SNOWFLAKE_WAREHOUSE=$(echo "$SNOWFLAKE_SECRET" | jq -r '.warehouse')
    SNOWFLAKE_DATABASE=$(echo "$SNOWFLAKE_SECRET" | jq -r '.database')
    SNOWFLAKE_SCHEMA=$(echo "$SNOWFLAKE_SECRET" | jq -r '.schema')
    
    # Get Tailscale auth key
    TAILSCALE_AUTH_KEY=$(aws secretsmanager get-secret-value --secret-id "tailscale-auth-key" --region us-east-2 --query 'SecretString' --output text)
    
    log_success "All secrets retrieved successfully"
}

# Function to deploy a CloudFormation stack
deploy_stack() {
    local stack_name=$1
    local template_file=$2
    local parameters=$3
    
    log "Deploying stack: $stack_name"
    
    if [ -n "$parameters" ]; then
        aws cloudformation deploy \
            --template-file "$template_file" \
            --stack-name "$stack_name" \
            --parameter-overrides $parameters \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
    else
        aws cloudformation deploy \
            --template-file "$template_file" \
            --stack-name "$stack_name" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION"
    fi
    
    if [ $? -eq 0 ]; then
        log_success "Stack $stack_name deployed successfully"
    else
        log_error "Failed to deploy stack $stack_name"
        exit 1
    fi
}

# Function to check stack status
check_stack_status() {
    local stack_name=$1
    local status=$(aws cloudformation describe-stacks --stack-name "$stack_name" --region "$REGION" --query 'Stacks[0].StackStatus' --output text 2>/dev/null)
    echo "$status"
}

# Function to wait for stack completion with enhanced progress tracking
wait_for_stack() {
    local stack_name=$1
    local max_attempts=60
    local attempt=1
    
    log "Waiting for stack $stack_name to complete..."
    log "This may take 5-15 minutes depending on the resources being created..."
    
    while [ $attempt -le $max_attempts ]; do
        local status=$(check_stack_status "$stack_name")
        local progress=$((attempt * 100 / max_attempts))
        
        case "$status" in
            "CREATE_COMPLETE"|"UPDATE_COMPLETE")
                log_success "Stack $stack_name completed successfully! ✓"
                return 0
                ;;
            "CREATE_FAILED"|"UPDATE_FAILED"|"ROLLBACK_COMPLETE"|"UPDATE_ROLLBACK_COMPLETE")
                log_error "Stack $stack_name failed with status: $status"
                log "Check the CloudFormation console for detailed error information:"
                log "https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks"
                return 1
                ;;
            "CREATE_IN_PROGRESS"|"UPDATE_IN_PROGRESS"|"UPDATE_ROLLBACK_IN_PROGRESS")
                log "Stack $stack_name is still in progress... [${progress}%] (attempt $attempt/$max_attempts)"
                log "Status: $status - This is normal, please wait..."
                sleep 30
                ;;
            *)
                log_warning "Unknown stack status: $status - continuing to wait..."
                sleep 30
                ;;
        esac
        
        ((attempt++))
    done
    
    log_error "Stack $stack_name did not complete within the expected time (30 minutes)"
    log "Check the CloudFormation console for current status:"
    log "https://console.aws.amazon.com/cloudformation/home?region=us-east-2#/stacks"
    return 1
}

# Main deployment function
deploy_all() {
    log "Starting Operations VPC deployment (Layered Approach)..."
    
    # Check prerequisites
    check_aws_cli
    get_secrets_from_aws
    
    # Deploy networking layer
    log "Phase 1: Deploying networking layer..."
    deploy_stack "${STACK_PREFIX}-networking" "${TEMPLATE_DIR}networking/vpc-subnets.yml"
    wait_for_stack "${STACK_PREFIX}-networking"
    
    # Get VPC ID from networking stack
    vpc_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)
    
    deploy_stack "${STACK_PREFIX}-security" "${TEMPLATE_DIR}networking/security-groups.yml" \
        "VpcId=$vpc_id DataOpsPostgresHost=$SQLMESH_POSTGRES_HOST DataOpsPostgresPort=$SQLMESH_POSTGRES_PORT DataOpsPostgresUser=$SQLMESH_POSTGRES_USER DataOpsPostgresPassword=$SQLMESH_POSTGRES_PASSWORD SnowflakeAccount=$SNOWFLAKE_ACCOUNT SnowflakeUser=$SNOWFLAKE_USER SnowflakePassword=$SNOWFLAKE_PASSWORD SnowflakeWarehouse=$SNOWFLAKE_WAREHOUSE SnowflakeDatabase=$SNOWFLAKE_DATABASE SnowflakeSchema=$SNOWFLAKE_SCHEMA TailscaleAuthKey=$TAILSCALE_AUTH_KEY"
    wait_for_stack "${STACK_PREFIX}-security"
    
    # Deploy data layer
    log "Phase 2: Deploying data layer..."
    # Get required parameters from previous stacks
    data_subnet1_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`DataSubnet1Id`].OutputValue' --output text)
    data_subnet2_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`DataSubnet2Id`].OutputValue' --output text)
    postgres_sg_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshPostgresSecurityGroupId`].OutputValue' --output text)
    deploy_stack "${STACK_PREFIX}-sqlmesh-db" "${TEMPLATE_DIR}data/sqlmesh-db.yml" \
        "VpcId=$vpc_id DataSubnet1Id=$data_subnet1_id DataSubnet2Id=$data_subnet2_id SqlmeshPostgresSecurityGroupId=$postgres_sg_id SqlmeshPostgresPassword=$SQLMESH_POSTGRES_PASSWORD"
    wait_for_stack "${STACK_PREFIX}-sqlmesh-db"
    
    # Deploy applications layer
    log "Phase 3: Deploying applications layer..."
    # Get required parameters from previous stacks
    public_subnet_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetId`].OutputValue' --output text)
    private_subnet_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' --output text)
    access_sg_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`AccessServerSecurityGroupId`].OutputValue' --output text)
    sqlmesh_sg_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshServerSecurityGroupId`].OutputValue' --output text)
    postgres_host=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-sqlmesh-db" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshPostgresEndpoint`].OutputValue' --output text)
    
    # Deploy Operations Host
    deploy_stack "${STACK_PREFIX}-operations-host" "${TEMPLATE_DIR}applications/operations-host.yml" \
        "VpcId=$vpc_id PublicSubnetId=$public_subnet_id AccessServerSecurityGroupId=$access_sg_id TailscaleAuthKey=$TAILSCALE_AUTH_KEY"
    wait_for_stack "${STACK_PREFIX}-operations-host"
    
    # Deploy SQLMesh Server
    deploy_stack "${STACK_PREFIX}-sqlmesh-server" "${TEMPLATE_DIR}applications/sqlmesh-server.yml" \
        "VpcId=$vpc_id PrivateSubnetId=$private_subnet_id SqlmeshServerSecurityGroupId=$sqlmesh_sg_id DataOpsPostgresHost=$postgres_host DataOpsPostgresPort=$SQLMESH_POSTGRES_PORT DataOpsPostgresUser=$SQLMESH_POSTGRES_USER DataOpsPostgresPassword=$SQLMESH_POSTGRES_PASSWORD DataOpsPostgresDatabase=$SQLMESH_POSTGRES_DATABASE SnowflakeAccount=$SNOWFLAKE_ACCOUNT SnowflakeUser=$SNOWFLAKE_USER SnowflakePassword=$SNOWFLAKE_PASSWORD SnowflakeWarehouse=$SNOWFLAKE_WAREHOUSE SnowflakeDatabase=$SNOWFLAKE_DATABASE SnowflakeSchema=$SNOWFLAKE_SCHEMA"
    wait_for_stack "${STACK_PREFIX}-sqlmesh-server"
    
    # Deploy DNS layer
    log "Phase 4: Deploying DNS layer..."
    deploy_stack "goodword-dns" "${TEMPLATE_DIR}../infrastructure/operations-vpc/dns/dns.yml" \
        "VpcId=$vpc_id Environment=$ENVIRONMENT PublicHostedZoneId=Z04032891ZM6L7J3T40M7"
    wait_for_stack "goodword-dns"
    
    log_success "All stacks deployed successfully!"
    
    # Display outputs
    log "Retrieving stack outputs..."
    aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs' --output table
    aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs' --output table
    aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-sqlmesh-db" --region "$REGION" --query 'Stacks[0].Outputs' --output table
    aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-operations-host" --region "$REGION" --query 'Stacks[0].Outputs' --output table
    aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-sqlmesh-server" --region "$REGION" --query 'Stacks[0].Outputs' --output table
}

# Function to show help
show_help() {
    echo "Operations VPC Deployment Script - Layered Approach"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --all              Deploy all stacks (networking, security, data, applications)"
    echo "  --networking       Deploy only networking layer (VPC, subnets)"
    echo "  --security         Deploy only security layer (security groups, secrets)"
    echo "  --data             Deploy only data layer (SQLMesh database)"
    echo "  --applications     Deploy only applications layer (both EC2 instances)"
    echo "  --operations-host  Deploy only operations host"
    echo "  --sqlmesh-server   Deploy only SQLMesh server"
    echo "  --sqlmesh-db       Deploy only SQLMesh database"
    echo "  --dns              Deploy only DNS configuration"
    echo "  --ssl-setup        Set up SSL certificate for SQLMesh server"
    echo "  --status           Show status of all stacks"
    echo "  --help             Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all                    # Deploy everything"
    echo "  $0 --networking             # Deploy only networking"
    echo "  $0 --operations-host        # Deploy only operations host"
    echo "  $0 --status                 # Check stack status"
}

# Function to show stack status
show_status() {
    log "Checking stack status..."
    
    local stacks=("${STACK_PREFIX}-networking" "${STACK_PREFIX}-security" "${STACK_PREFIX}-sqlmesh-db" "${STACK_PREFIX}-operations-host" "${STACK_PREFIX}-sqlmesh-server" "goodword-dns")
    
    for stack in "${stacks[@]}"; do
        local status=$(check_stack_status "$stack")
        if [ "$status" = "None" ]; then
            log_warning "Stack $stack does not exist"
        else
            log "Stack $stack: $status"
        fi
    done
}

# Function to set up SSL certificate
setup_ssl() {
    log "Setting up SSL certificate for SQLMesh server..."
    
    # Check if ssl-manager.sh exists
    if [ ! -f "./scripts/ssl-manager.sh" ]; then
        log_error "SSL manager script not found at ./scripts/ssl-manager.sh"
        exit 1
    fi
    
    # Make it executable
    chmod +x ./scripts/ssl-manager.sh
    
    # Run SSL setup
    log "Running SSL certificate setup..."
    ./scripts/ssl-manager.sh setup
    
    if [ $? -eq 0 ]; then
        log_success "SSL certificate setup completed successfully!"
        log "You can now access SQLMesh at: https://sqlmesh.internal.goodword.cloud"
    else
        log_warning "SSL certificate setup encountered issues"
        log "You can retry with: ./scripts/ssl-manager.sh retry"
        log "Or check DNS propagation with: ./scripts/ssl-manager.sh check"
    fi
}

# Main script logic
case "${1:-}" in
    --all)
        deploy_all
        ;;
    --networking)
        deploy_stack "${STACK_PREFIX}-networking" "${TEMPLATE_DIR}networking/vpc-subnets.yml"
        ;;
    --security)
        check_aws_cli
        get_secrets_from_aws
        # Get VPC ID from networking stack
        vpc_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)
        deploy_stack "${STACK_PREFIX}-security" "${TEMPLATE_DIR}networking/security-groups.yml" \
            "VpcId=$vpc_id DataOpsPostgresHost=$SQLMESH_POSTGRES_HOST DataOpsPostgresPort=$SQLMESH_POSTGRES_PORT DataOpsPostgresUser=$SQLMESH_POSTGRES_USER DataOpsPostgresPassword=$SQLMESH_POSTGRES_PASSWORD SnowflakeAccount=$SNOWFLAKE_ACCOUNT SnowflakeUser=$SNOWFLAKE_USER SnowflakePassword=$SNOWFLAKE_PASSWORD SnowflakeWarehouse=$SNOWFLAKE_WAREHOUSE SnowflakeDatabase=$SNOWFLAKE_DATABASE SnowflakeSchema=$SNOWFLAKE_SCHEMA TailscaleAuthKey=$TAILSCALE_AUTH_KEY"
        ;;
    --data)
        check_aws_cli
        get_secrets_from_aws
        # Get required parameters from previous stacks
        vpc_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)
        data_subnet1_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`DataSubnet1Id`].OutputValue' --output text)
        data_subnet2_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`DataSubnet2Id`].OutputValue' --output text)
        postgres_sg_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshPostgresSecurityGroupId`].OutputValue' --output text)
        deploy_stack "${STACK_PREFIX}-sqlmesh-db" "${TEMPLATE_DIR}data/sqlmesh-db.yml" \
            "VpcId=$vpc_id DataSubnet1Id=$data_subnet1_id DataSubnet2Id=$data_subnet2_id SqlmeshPostgresSecurityGroupId=$postgres_sg_id SqlmeshPostgresPassword=$SQLMESH_POSTGRES_PASSWORD"
        ;;
    --applications)
        check_aws_cli
        get_secrets_from_aws
        # Get required parameters from previous stacks
        vpc_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)
        public_subnet_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`PublicSubnetId`].OutputValue' --output text)
        private_subnet_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`PrivateSubnetId`].OutputValue' --output text)
        access_sg_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`AccessServerSecurityGroupId`].OutputValue' --output text)
        sqlmesh_sg_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-security" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshServerSecurityGroupId`].OutputValue' --output text)
        postgres_host=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-sqlmesh-db" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`SqlmeshPostgresEndpoint`].OutputValue' --output text)
        
        # Deploy Operations Host
        deploy_stack "${STACK_PREFIX}-operations-host" "${TEMPLATE_DIR}applications/operations-host.yml" \
            "VpcId=$vpc_id PublicSubnetId=$public_subnet_id AccessServerSecurityGroupId=$access_sg_id TailscaleAuthKey=$TAILSCALE_AUTH_KEY"
        
        # Deploy SQLMesh Server
        deploy_stack "${STACK_PREFIX}-sqlmesh-server" "${TEMPLATE_DIR}applications/sqlmesh-server.yml" \
            "VpcId=$vpc_id PrivateSubnetId=$private_subnet_id SqlmeshServerSecurityGroupId=$sqlmesh_sg_id DataOpsPostgresHost=$postgres_host DataOpsPostgresPort=$SQLMESH_POSTGRES_PORT DataOpsPostgresUser=$SQLMESH_POSTGRES_USER DataOpsPostgresPassword=$SQLMESH_POSTGRES_PASSWORD DataOpsPostgresDatabase=$SQLMESH_POSTGRES_DATABASE SnowflakeAccount=$SNOWFLAKE_ACCOUNT SnowflakeUser=$SNOWFLAKE_USER SnowflakePassword=$SNOWFLAKE_PASSWORD SnowflakeWarehouse=$SNOWFLAKE_WAREHOUSE SnowflakeDatabase=$SNOWFLAKE_DATABASE SnowflakeSchema=$SNOWFLAKE_SCHEMA"
        ;;
    --operations-host)
        deploy_stack "${STACK_PREFIX}-operations-host" "${TEMPLATE_DIR}applications/operations-host.yml"
        ;;
    --sqlmesh-server)
        deploy_stack "${STACK_PREFIX}-sqlmesh-server" "${TEMPLATE_DIR}applications/sqlmesh-server.yml"
        ;;
    --sqlmesh-db)
        check_aws_cli
        get_secrets_from_aws
        deploy_stack "${STACK_PREFIX}-sqlmesh-db" "${TEMPLATE_DIR}data/sqlmesh-db.yml" \
            "SqlmeshPostgresPassword=$SQLMESH_POSTGRES_PASSWORD"
        ;;
    --dns)
        check_aws_cli
        # Get VPC ID from networking stack
        vpc_id=$(aws cloudformation describe-stacks --stack-name "${STACK_PREFIX}-networking" --region "$REGION" --query 'Stacks[0].Outputs[?OutputKey==`VpcId`].OutputValue' --output text)
        deploy_stack "goodword-dns" "${TEMPLATE_DIR}../infrastructure/operations-vpc/dns/dns.yml" \
            "VpcId=$vpc_id Environment=$ENVIRONMENT PublicHostedZoneId=Z04032891ZM6L7J3T40M7"
        ;;
    --ssl-setup)
        setup_ssl
        ;;
    --status)
        show_status
        ;;
    --help|help|-h)
        show_help
        ;;
    *)
        log_error "Invalid option: ${1:-}"
        show_help
        exit 1
        ;;
esac
#!/bin/bash
# ssl-manager.sh - Unified SSL certificate management for SQLMesh
# Usage: ./ssl-manager.sh [check|setup|retry|daily]

set -euo pipefail

# Configuration
DOMAIN="sqlmesh.internal.goodword.cloud"
REGION="us-east-2"
STACK_NAME="ops-vpc-sqlmesh-server"
SQLMESH_INSTANCE_ID="i-03519bd309babd741"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check DNS propagation
check_dns_propagation() {
    log_info "Checking DNS propagation for $DOMAIN..."
    
    # Get expected IP from Route 53
    EXPECTED_IP=$(aws route53 list-resource-record-sets \
        --hosted-zone-id Z1D633PJN98FT9 \
        --query "ResourceRecordSets[?Name=='$DOMAIN.'].ResourceRecords[0].Value" \
        --output text 2>/dev/null || echo "")
    
    if [ -z "$EXPECTED_IP" ]; then
        log_error "Could not get expected IP from Route 53"
        return 1
    fi
    
    log_info "Expected IP: $EXPECTED_IP"
    
    # Check from multiple DNS servers
    local ALL_GOOD=true
    
    # Google DNS
    log_info "Checking from Google DNS (8.8.8.8):"
    if nslookup "$DOMAIN" 8.8.8.8 | grep -q "$EXPECTED_IP"; then
        log_success "✅ Resolving correctly to $EXPECTED_IP"
    else
        log_error "❌ Not resolving correctly from Google DNS"
        ALL_GOOD=false
    fi
    
    # Cloudflare DNS
    log_info "Checking from Cloudflare DNS (1.1.1.1):"
    if nslookup "$DOMAIN" 1.1.1.1 | grep -q "$EXPECTED_IP"; then
        log_success "✅ Resolving correctly to $EXPECTED_IP"
    else
        log_error "❌ Not resolving correctly from Cloudflare DNS"
        ALL_GOOD=false
    fi
    
    # OpenDNS
    log_info "Checking from OpenDNS (208.67.222.222):"
    if nslookup "$DOMAIN" 208.67.222.222 | grep -q "$EXPECTED_IP"; then
        log_success "✅ Resolving correctly to $EXPECTED_IP"
    else
        log_error "❌ Not resolving correctly from OpenDNS"
        ALL_GOOD=false
    fi
    
    # Quad9
    log_info "Checking from Quad9 (9.9.9.9):"
    if nslookup "$DOMAIN" 9.9.9.9 | grep -q "$EXPECTED_IP"; then
        log_success "✅ Resolving correctly to $EXPECTED_IP"
    else
        log_error "❌ Not resolving correctly from Quad9"
        ALL_GOOD=false
    fi
    
    if [ "$ALL_GOOD" = true ]; then
        log_success "🎉 DNS propagation looks good across all servers!"
        return 0
    else
        log_warning "⚠️  DNS propagation is not complete yet"
        return 1
    fi
}

# Temporarily open port 80 for Let's Encrypt
open_port_80() {
    log_info "Temporarily opening port 80 for Let's Encrypt validation..."
    
    aws ec2 authorize-security-group-ingress \
        --group-id sg-0cffc1cd8ed8e3f0f \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$REGION" 2>/dev/null || log_warning "Port 80 rule may already exist"
}

# Close port 80 after Let's Encrypt
close_port_80() {
    log_info "Closing port 80 after Let's Encrypt validation..."
    
    aws ec2 revoke-security-group-ingress \
        --group-id sg-0cffc1cd8ed8e3f0f \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --region "$REGION" 2>/dev/null || log_warning "Port 80 rule may not exist"
}

# Setup SSL certificate
setup_ssl() {
    log_info "Setting up SSL certificate for $DOMAIN..."
    
    # Check DNS propagation first
    if ! check_dns_propagation; then
        log_warning "DNS propagation not complete, but attempting SSL setup anyway..."
    fi
    
    # Open port 80 temporarily
    open_port_80
    
    # Wait a moment for security group update
    sleep 10
    
    # Attempt to get SSL certificate
    log_info "Attempting to get SSL certificate from Let's Encrypt..."
    aws ssm send-command \
        --instance-ids "$SQLMESH_INSTANCE_ID" \
        --document-name "AWS-RunShellScript" \
        --parameters "commands=[
            \"certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@goodword.cloud --redirect\"
        ]" \
        --region "$REGION" \
        --query 'Command.CommandId' \
        --output text > /tmp/certbot_cmd.txt
    
    COMMAND_ID=$(cat /tmp/certbot_cmd.txt)
    log_info "Command ID: $COMMAND_ID"
    
    # Wait for command to complete
    log_info "Waiting for certificate generation to complete..."
    aws ssm wait command-executed \
        --command-id "$COMMAND_ID" \
        --instance-id "$SQLMESH_INSTANCE_ID" \
        --region "$REGION"
    
    # Get command output
    aws ssm get-command-invocation \
        --command-id "$COMMAND_ID" \
        --instance-id "$SQLMESH_INSTANCE_ID" \
        --region "$REGION" \
        --query 'StandardOutputContent' \
        --output text
    
    # Close port 80
    close_port_80
    
    # Test HTTPS access
    log_info "Testing HTTPS access..."
    if curl -s -k "https://$DOMAIN" | grep -q "SQLMesh"; then
        log_success "🎉 HTTPS is working! SSL certificate setup complete."
    else
        log_warning "HTTPS test failed, but certificate may still be valid"
    fi
}

# Retry SSL setup
retry_ssl() {
    log_info "Retrying SSL certificate setup..."
    setup_ssl
}

# Daily check and retry
daily_check() {
    log_info "Running daily SSL check for $DOMAIN..."
    
    # Check if HTTPS is already working
    if curl -s -k "https://$DOMAIN" | grep -q "SQLMesh"; then
        log_success "✅ HTTPS is already working, no action needed"
        return 0
    fi
    
    # Check DNS propagation
    if check_dns_propagation; then
        log_info "DNS propagation looks good, attempting SSL setup..."
        setup_ssl
    else
        log_warning "DNS propagation not complete, will retry tomorrow"
    fi
}

# Main script logic
main() {
    local action=${1:-check}
    
    case "$action" in
        "check")
            check_dns_propagation
            ;;
        "setup")
            setup_ssl
            ;;
        "retry")
            retry_ssl
            ;;
        "daily")
            daily_check
            ;;
        *)
            echo "Usage: $0 [check|setup|retry|daily]"
            echo ""
            echo "Actions:"
            echo "  check  - Check DNS propagation status"
            echo "  setup  - Set up SSL certificate (with temporary port 80 opening)"
            echo "  retry  - Retry SSL certificate setup"
            echo "  daily  - Daily check and retry (for cron job)"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"

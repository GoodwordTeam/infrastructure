#!/bin/bash
# Ops Host Access Configuration - AWS Commands
# Created: $(date)
# Purpose: Configure ops-host access to all services across both VPCs
# Author: Chris Patrick

echo "=== Ops Host Access Configuration ==="
echo "This script configures security groups and routing for ops-host access"
echo ""

# =============================================================================
# 1. ICMP (Ping) Access - Initial Setup
# =============================================================================
echo "1. Adding ICMP access to existing security groups..."

# Goodword RDS Security Group - ICMP
aws ec2 authorize-security-group-ingress \
  --group-id sg-0741d72a0d20e1ddf \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

# Private Resources Security Group - ICMP
aws ec2 authorize-security-group-ingress \
  --group-id sg-0df6339d355b2c7bb \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

echo "✅ ICMP access added to existing groups"
echo ""

# =============================================================================
# 2. Specific Service Access
# =============================================================================
echo "2. Adding specific service access..."

# VPN Mesh Server - SSH Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0d8c74a9cdf463253 \
  --protocol tcp \
  --port 22 \
  --source-group sg-0cffc1cd8ed8e3f0f

# Goodword RDS - PostgreSQL Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0741d72a0d20e1ddf \
  --protocol tcp \
  --port 5432 \
  --source-group sg-0cffc1cd8ed8e3f0f

# Private Resources - HTTP Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0df6339d355b2c7bb \
  --protocol tcp \
  --port 80 \
  --source-group sg-0cffc1cd8ed8e3f0f

# Private Resources - HTTPS Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0df6339d355b2c7bb \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

echo "✅ Specific service access added"
echo ""

# =============================================================================
# 3. External Data Service Groups - HTTPS Access
# =============================================================================
echo "3. Adding HTTPS access to External Data Service Lambda functions..."

# Lambda Functions (4 groups) - HTTPS Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-09f80a81ebe77cce1 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0a05af1351ba64e55 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0b26dc740a2fc54e6 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0102ad84d2fbbda16 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

echo "✅ Lambda function HTTPS access added"
echo ""

# =============================================================================
# 4. External Data Service RDS Groups - PostgreSQL Access
# =============================================================================
echo "4. Adding PostgreSQL access to External Data Service RDS groups..."

# RDS Security Groups (2 groups) - PostgreSQL Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0b3519e1710658eac \
  --protocol tcp \
  --port 5432 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0825b898876a9c59d \
  --protocol tcp \
  --port 5432 \
  --source-group sg-0cffc1cd8ed8e3f0f

echo "✅ RDS PostgreSQL access added"
echo ""

# =============================================================================
# 5. VPC Endpoint and Glue Access
# =============================================================================
echo "5. Adding access to VPC Endpoint and Glue services..."

# VPC Endpoint Security Group - HTTPS Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0ec2955ec032fdf18 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

# Glue Security Group - HTTPS Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0a42e88ead0aa9870 \
  --protocol tcp \
  --port 443 \
  --source-group sg-0cffc1cd8ed8e3f0f

echo "✅ VPC Endpoint and Glue access added"
echo ""

# =============================================================================
# 6. External Data Service Groups - ICMP Access
# =============================================================================
echo "6. Adding ICMP access to all External Data Service groups..."

# Lambda Functions - ICMP Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-09f80a81ebe77cce1 \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0a05af1351ba64e55 \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0b26dc740a2fc54e6 \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0102ad84d2fbbda16 \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

# RDS Security Groups - ICMP Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0b3519e1710658eac \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

aws ec2 authorize-security-group-ingress \
  --group-id sg-0825b898876a9c59d \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

# VPC Endpoint Security Group - ICMP Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0ec2955ec032fdf18 \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

# Glue Security Group - ICMP Access
aws ec2 authorize-security-group-ingress \
  --group-id sg-0a42e88ead0aa9870 \
  --protocol icmp \
  --port -1 \
  --source-group sg-0cffc1cd8ed8e3f0f

echo "✅ ICMP access added to all External Data Service groups"
echo ""

# =============================================================================
# 7. Routing Configuration - Aurora Cluster Access
# =============================================================================
echo "7. Adding routing for Aurora cluster access..."

# Route Table 1 (subnet-0cd2d4a8fea31f34b) - Route to ops-vpc
aws ec2 create-route \
  --route-table-id rtb-05f0fe3c6ffa86158 \
  --destination-cidr-block 172.22.0.0/16 \
  --vpc-peering-connection-id pcx-093256f9adcfae896

# Route Table 2 (subnet-07a613a57b037e3a6) - Route to ops-vpc
aws ec2 create-route \
  --route-table-id rtb-03eb3281b00677a15 \
  --destination-cidr-block 172.22.0.0/16 \
  --vpc-peering-connection-id pcx-093256f9adcfae896

echo "✅ Aurora cluster routing configured"
echo ""

# =============================================================================
# 8. Summary
# =============================================================================
echo "=== CONFIGURATION COMPLETE ==="
echo ""
echo "Security Groups Modified: 10 total"
echo "- 2 existing groups (Goodword RDS, Private Resources, VPN Mesh Server)"
echo "- 8 External Data Service groups (Lambda, RDS, VPC Endpoint, Glue)"
echo ""
echo "Rules Added: 18 total"
echo "- ICMP rules: 10 groups"
echo "- HTTPS rules: 6 groups"
echo "- PostgreSQL rules: 3 groups"
echo "- SSH rules: 1 group"
echo "- HTTP rules: 1 group"
echo ""
echo "Route Tables Modified: 2 total"
echo "- Aurora cluster subnets now have routes to ops-vpc (172.22.0.0/16)"
echo ""
echo "✅ Ops-host now has access to all services across both VPCs!"
echo ""

# =============================================================================
# 9. Verification Commands (Optional)
# =============================================================================
echo "=== VERIFICATION COMMANDS ==="
echo ""
echo "To test connectivity from ops-host:"
echo "ssh -i ~/.ssh/ops-vpc-key.pem ec2-user@operations.internal.goodword.cloud"
echo ""
echo "Test ICMP:"
echo "ping -c 3 172.22.2.106  # SQLMesh server"
echo ""
echo "Test Database Connectivity:"
echo "nc -zv prod-goodword-data-operations-instance-v3.cbys2uie40p0.us-east-2.rds.amazonaws.com 5432"
echo "nc -zv externaldataservice-auroracluster23d869c0-vfh3or6gsqjq.cluster-cbys2uie40p0.us-east-2.rds.amazonaws.com 5432"
echo ""
echo "Test HTTPS Access:"
echo "curl -k https://<lambda-endpoint>"
echo ""

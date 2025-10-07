#!/bin/bash
set -e

# Configuration
STACK_NAME="goodword-dns"
TEMPLATE_FILE="dns/domains.yml"
REGION="us-east-2"
ENVIRONMENT="ops"

echo "🌐 Deploying comprehensive DNS configuration for goodword.cloud..."

# Get VPC ID automatically
VPC_ID=$(aws ec2 describe-vpcs \
  --filters "Name=tag:Name,Values=ops-vpc" \
  --query 'Vpcs[0].VpcId' \
  --output text \
  --region $REGION)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
  echo "❌ Error: Could not find VPC with name 'ops-vpc'"
  echo "Available VPCs:"
  aws ec2 describe-vpcs --query 'Vpcs[*].[VpcId,Tags[?Key==`Name`].Value|[0]]' --output table --region $REGION
  exit 1
fi

echo "📍 Using VPC: $VPC_ID"

# Deploy the DNS stack
echo "🚀 Deploying DNS stack..."

aws cloudformation deploy \
  --template-file $TEMPLATE_FILE \
  --stack-name $STACK_NAME \
  --region $REGION \
  --parameter-overrides \
    VpcId=$VPC_ID \
    Environment=$ENVIRONMENT \
    PublicHostedZoneId=Z04032891ZM6L7J3T40M7 \
  --capabilities CAPABILITY_IAM

echo ""
echo "✅ DNS stack deployed successfully!"
echo ""
echo "🌍 Public Endpoints (goodword.cloud - existing services):"
echo "   • api.goodword.cloud"
echo "   • data-operations-db.goodword.cloud"
echo "   • db.goodword.cloud"
echo "   • klavitron.goodword.cloud"
echo ""
echo "🌐 Public Internal Endpoints (goodword.cloud - accessible from anywhere):"
echo "   • sqlmesh.goodword.cloud → 172.22.2.106"
echo "   • postgres.goodword.cloud → 172.22.4.203"
echo "   • operations.goodword.cloud → 172.22.1.10"
echo ""
echo "🏠 Internal Subdomain (internal.goodword.cloud - publicly resolvable with private IPs):"
echo "   • sqlmesh.internal.goodword.cloud → 172.22.2.106"
echo "   • postgres.internal.goodword.cloud → 172.22.4.203"
echo "   • operations.internal.goodword.cloud → 172.22.1.10"
echo ""
echo "📝 Usage (choose your preferred method):"
echo "   # Direct public DNS (works from anywhere):"
echo "   ssh -i ~/.ssh/ops-vpc-key.pem ec2-user@sqlmesh.goodword.cloud"
echo "   http://sqlmesh.goodword.cloud:8000"
echo ""
echo "   # Internal subdomain (publicly resolvable, private IPs for obscurity):"
echo "   ssh -i ~/.ssh/ops-vpc-key.pem ec2-user@sqlmesh.internal.goodword.cloud"
echo "   http://sqlmesh.internal.goodword.cloud:8000"
echo ""
echo "🎉 DNS configuration complete!"

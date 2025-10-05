# Operations VPC - Layered Architecture

## 🏗️ **Architecture Overview**

The Operations VPC is designed using a layered approach for maximum safety and granular control. Each layer can be deployed independently, allowing for safer updates and easier troubleshooting.

### **VPC Design**
- **VPC Name**: `ops-vpc`
- **CIDR Block**: `172.22.0.0/16`
- **Region**: `us-east-2`

### **Subnet Layout**
- **Public Subnet**: `172.22.1.0/24` (AZ: us-east-2a)
- **Private Subnet**: `172.22.2.0/24` (AZ: us-east-2a)  
- **Data Subnet 1**: `172.22.3.0/24` (AZ: us-east-2a) ← RDS deploys here
- **Data Subnet 2**: `172.22.4.0/24` (AZ: us-east-2b) ← Required by AWS, unused

### **Services**
- **Operations Host**: t3.small EC2 instance with RustDesk + Tailscale
- **SQLMesh Server**: t3.medium EC2 instance with Docker + SQLMesh UI
- **SQLMesh Database**: Aurora PostgreSQL Serverless for state storage
- **S3 Bucket**: For SQLMesh artifacts (source code, config files)

### **RDS Subnet Group Requirement**
AWS RDS requires DB subnet groups to span at least 2 availability zones, even for single-AZ deployments. Data Subnet 2 exists solely to satisfy this AWS requirement and remains unused (~$7/month cost).

### **VPC Diagram**
```
Operations VPC (172.22.0.0/16)
├── Public Subnet (172.22.1.0/24) - us-east-2a
│   ├── Operations Host (t3.small)
│   │   ├── RustDesk Server
│   │   └── Tailscale (advertises 172.22.0.0/16)
│   └── NAT Gateway
├── Private Subnet (172.22.2.0/24) - us-east-2a  
│   └── SQLMesh Server (t3.medium)
│       ├── Docker
│       └── SQLMesh UI + Scheduler
└── Data Subnets (RDS Requirement)
    ├── Data Subnet 1 (172.22.3.0/24) - us-east-2a
    │   └── SQLMesh PostgreSQL (Aurora Serverless) ← Deploys here
    └── Data Subnet 2 (172.22.4.0/24) - us-east-2b
        └── (Unused - AWS requirement only)

VPC Peering: ops-vpc ↔ goodword-vpc (172.20.0.0/16)
```

## 📁 **File Structure**

```
infrastructure/operations-vpc/
├── networking/
│   ├── vpc-subnets.yml        # VPC, subnets, internet gateway, NAT gateway
│   └── security-groups.yml    # Security groups, VPC peering, SSM parameters
├── applications/
│   ├── operations-host.yml    # Operations Host EC2 + IAM + monitoring
│   └── sqlmesh-server.yml     # SQLMesh Server EC2 + IAM + S3 + monitoring
├── data/
│   └── sqlmesh-db.yml         # SQLMesh PostgreSQL RDS + DB subnet group
├── scripts/
│   ├── deploy.sh              # Master deployment script with layered flags
│   └── status-monitor.sh      # Status checking utilities
├── README.md                  # This documentation
└── DEPLOYMENT_PLAN.md         # Detailed deployment plan
```

## 🚀 **Deployment Commands**

### **Deploy Everything (First Time)**
```bash
cd infrastructure/operations-vpc
./scripts/deploy.sh --all
```

### **Deploy Individual Layers**
```bash
# Deploy networking layer
./scripts/deploy.sh --networking

# Deploy security layer (requires secrets)
./scripts/deploy.sh --security

# Deploy data layer
./scripts/deploy.sh --data

# Deploy applications layer
./scripts/deploy.sh --applications
```

### **Deploy Individual Services**
```bash
# Deploy only operations host
./scripts/deploy.sh --operations-host

# Deploy only SQLMesh server
./scripts/deploy.sh --sqlmesh-server

# Deploy only SQLMesh database
./scripts/deploy.sh --sqlmesh-db
```

### **Check Status**
```bash
./scripts/deploy.sh --status
```

## 🔧 **Configuration**

### **Secrets Management**
All secrets are stored in AWS Secrets Manager and automatically retrieved during deployment:
- **PostgreSQL**: `aurora-data-operations` secret
- **Snowflake**: `snowflake-warehouse` secret  
- **Tailscale**: `tailscale-auth-key` secret

### **Key Pairs**
- **Key Pair Name**: `ops-vpc-key` (dedicated for this VPC)
- **Purpose**: SSH access to EC2 instances

### **Security Groups**
- **Access Server**: SSH (22), RustDesk (21115-21116), Tailscale (41641)
- **SQLMesh Server**: SSH (22), SQLMesh UI (8000)
- **SQLMesh PostgreSQL**: PostgreSQL (5432)

## 📊 **Monitoring**

### **CloudWatch Logs**
- **Operations Host**: `/aws/ec2/ops-access-server`
- **SQLMesh Server**: `/aws/ec2/ops-sqlmesh-server`

### **Status Monitoring**
The deployment script includes real-time status monitoring with:
- Progress updates every 30 seconds
- Color-coded output (success, warning, error)
- Automatic retry logic
- Detailed error reporting

## 🔐 **Security**

### **Network Security**
- Private subnets for database and application servers
- Public subnet only for operations host (with Elastic IP)
- VPC peering to GoodWord VPC for cross-VPC communication
- NAT Gateway for outbound internet access from private subnets

### **Access Control**
- IAM roles with minimal required permissions
- Security groups with least-privilege access
- SSM Parameter Store for secure configuration
- No hardcoded credentials in templates

## 🛠️ **Troubleshooting**

### **Common Issues**
1. **AWS CLI not configured**: Run `aws sso login`
2. **Secrets not found**: Verify secrets exist in AWS Secrets Manager
3. **Stack deployment fails**: Check CloudFormation console for detailed errors
4. **Instance not accessible**: Verify security groups and key pair

### **Useful Commands**
```bash
# Check AWS credentials
aws sts get-caller-identity

# List all stacks
aws cloudformation list-stacks --region us-east-2

# Get stack details
aws cloudformation describe-stacks --stack-name ops-vpc-networking --region us-east-2

# Check instance status
aws ec2 describe-instances --region us-east-2 --filters "Name=tag:Name,Values=ops-access-server"
```

## 📋 **Deployment Order**

1. **Networking Layer**: VPC, subnets, internet gateway, NAT gateway
2. **Security Layer**: Security groups, VPC peering, SSM parameters
3. **Data Layer**: SQLMesh PostgreSQL database
4. **Applications Layer**: Operations host and SQLMesh server

## 🔄 **Updates and Maintenance**

### **Safe Updates**
- Each layer can be updated independently
- CloudFormation only replaces resources when definitions change significantly
- Minor changes (tags, security group rules) don't cause resource replacement

### **Rollback Strategy**
- CloudFormation automatically rolls back failed deployments
- Each layer can be rolled back independently
- Previous working state is preserved

## 📞 **Support**

For issues or questions:
1. Check the troubleshooting section above
2. Review CloudFormation stack events
3. Check CloudWatch logs for application-specific issues
4. Verify all prerequisites are met (AWS CLI, secrets, key pairs)
# Snowflake VPC Integration Plan

## Overview

This document outlines the comprehensive plan for integrating Snowflake with the Operations VPC to enable secure, private connectivity for SQLMesh server access. The plan leverages existing infrastructure and provides a cost-effective, secure solution.

## Current Infrastructure Audit (us-east-2)

### VPC Architecture

#### 1. Operations VPC (`ops-vpc`) - `172.22.0.0/16`
- **VPC ID**: `vpc-0f0a0744e35746a67`
- **Purpose**: Operations and data hub (persistent, long-lived)
- **Status**: ✅ Active and running

**Subnets:**
- **Public**: `172.22.1.0/24` (us-east-2a) - `ops-public-subnet`
- **Private**: `172.22.2.0/24` (us-east-2a) - `ops-private-subnet`
- **Data**: `172.22.3.0/24` (us-east-2a) - `ops-data-subnet-1`
- **Data**: `172.22.4.0/24` (us-east-2b) - `ops-data-subnet-2`

#### 2. Goodword VPC (`goodwordvpc-vpc`) - `172.20.0.0/16`
- **VPC ID**: `vpc-07ee3805f07edfac1`
- **Purpose**: Production environment
- **Status**: ✅ Active and running

**Subnets:**
- **Public**: `172.20.0.0/23`, `172.20.20.0/23`
- **Private**: `172.20.40.0/23`, `172.20.60.0/23`, `172.20.80.0/23`, `172.20.100.0/23`
- **Data**: `172.20.140.0/23`

#### 3. Old VPC (`old-vpc`) - `172.31.0.0/16`
- **VPC ID**: `vpc-0de7235fc850cfd6c`
- **Purpose**: Legacy infrastructure
- **Status**: ⚠️ Legacy (has existing VPC endpoints)

### Current Infrastructure Components

#### Operations VPC Resources

**EC2 Instances:**
- `ops-access-server` (t3.small)
  - Private IP: `172.22.1.15`
  - Public IP: `3.136.236.15`
  - Purpose: Access server (RustDesk + Tailscale)
  - Subnet: Public

- `ops-sqlmesh-server` (t3.medium)
  - Private IP: `172.22.2.106`
  - Public IP: None (private only)
  - Purpose: SQLMesh server
  - Subnet: Private

**RDS Databases:**
- `ops-sqlmesh-postgres` (db.t3.micro) - PostgreSQL
- `externaldataservice-auroraclusterwriteraa1ab06c-gzmjcjq0x37o` (db.serverless) - Aurora PostgreSQL

**Security Groups:**
- `ops-sqlmesh-postgres-sg` - SQLMesh PostgreSQL
- `ops-access-server-sg` - Access Server (RustDesk + Tailscale)
- `ops-sqlmesh-server-sg` - SQLMesh Server

#### Goodword VPC Resources

**RDS Databases:**
- `prod-goodword-data-operations-instance-v3` (db.serverless) - Aurora PostgreSQL
- `prod-goodword-db2-instance-1` (db.r5.xlarge) - Aurora PostgreSQL
- `prod-goodword-db2-instance-1-us-east-2a` (db.r5.xlarge) - Aurora PostgreSQL

### Existing VPC Endpoints

#### Old VPC (vpc-0de7235fc850cfd6c):
- **S3 Gateway Endpoint**: `vpce-0ce54dfdb300ef79f`
- **Secrets Manager Interface Endpoint**: `vpce-0dbf0383ad686a0d6`
- **SSM Interface Endpoint**: `vpce-02892ab907b5b829b`

#### Goodword VPC (vpc-07ee3805f07edfac1):
- **S3 Gateway Endpoint**: `vpce-049c1d4bb1b32cc62`

#### Operations VPC:
- **No existing VPC endpoints** - Clean slate for Snowflake integration

### CloudFormation Stacks (us-east-2)

**Operations VPC Stacks:**
- `ops-vpc-networking` - VPC and subnets
- `ops-vpc-security` - Security groups
- `ops-vpc-sqlmesh-db` - SQLMesh database
- `ops-vpc-operations-host` - Operations host
- `ops-vpc-sqlmesh-server` - SQLMesh server

**Other Stacks:**
- `klavitron` - Klaviyo integration
- `klaviyo-warehouse-airtable-sync` - Data sync
- `goodword-data-operations` - Data operations
- Various dev and staging services

## Snowflake Integration Strategy

### Why Operations VPC?

1. **Persistent Infrastructure**: Operations VPC is designed to be long-lived and persistent
2. **Centralized Data Hub**: Acts as the central data management point
3. **Cross-VPC Access**: Can access all other VPCs (production, dev)
4. **Security Isolation**: Production and Dev VPCs remain isolated
5. **Cost Efficiency**: Single Snowflake connection for all environments

### Architecture Design

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Snowflake     │───▶│  Operations VPC  │───▶│  Goodword VPC   │
│   (Private)     │    │  (Data Hub)      │    │  (Production)   │
│                 │    │  172.22.0.0/16   │    │  172.20.0.0/16  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │  Development VPC│
                       │  (Future)       │
                       │  172.21.0.0/16  │
                       └─────────────────┘
```

## Implementation Plan

### Phase 1: VPC Endpoint Configuration

#### 1.1 Create VPC Endpoint in Operations VPC

**CloudFormation Template Addition:**
```yaml
# Add to operations-vpc CloudFormation
SQLMeshVPCEndpoint:
  Type: AWS::EC2::VPCEndpoint
  Properties:
    VpcId: !Ref OperationsVpc
    ServiceName: com.amazonaws.us-east-2.execute-api
    VpcEndpointType: Interface
    SubnetIds:
      - !Ref PrivateSubnet  # 172.22.2.0/24
    SecurityGroupIds:
      - !Ref SQLMeshVPCEndpointSecurityGroup
    PrivateDnsEnabled: true
    PolicyDocument:
      Version: '2012-10-17'
      Statement:
        - Effect: Allow
          Principal: '*'
          Action: 'execute-api:Invoke'
          Resource: '*'
```

#### 1.2 Security Group for VPC Endpoint

```yaml
SQLMeshVPCEndpointSecurityGroup:
  Type: AWS::EC2::SecurityGroup
  Properties:
    GroupDescription: VPC Endpoint Security Group for SQLMesh
    SecurityGroupIngress:
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 172.22.0.0/16  # Operations VPC
        Description: HTTPS from Operations VPC
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 172.20.0.0/16  # Goodword VPC (future peering)
        Description: HTTPS from Goodword VPC
      - IpProtocol: tcp
        FromPort: 443
        ToPort: 443
        CidrIp: 10.0.0.0/8     # Snowflake IP ranges
        Description: HTTPS from Snowflake
```

### Phase 2: VPC Peering Setup

#### 2.1 Operations to Goodword VPC Peering

```yaml
OperationsToGoodwordPeering:
  Type: AWS::EC2::VPCPeeringConnection
  Properties:
    VpcId: !Ref OperationsVpc
    PeerVpcId: !Ref GoodwordVpc
    Tags:
      - Key: Name
        Value: ops-to-goodword-peering
```

#### 2.2 Route Table Updates

```yaml
# Operations VPC Route Table
OperationsRouteTable:
  Type: AWS::EC2::RouteTable
  Properties:
    VpcId: !Ref OperationsVpc
    Routes:
      - DestinationCidrBlock: 0.0.0.0/0
        GatewayId: !Ref InternetGateway
      - DestinationCidrBlock: 172.20.0.0/16
        VpcPeeringConnectionId: !Ref OperationsToGoodwordPeering

# Goodword VPC Route Table
GoodwordRouteTable:
  Type: AWS::EC2::RouteTable
  Properties:
    VpcId: !Ref GoodwordVpc
    Routes:
      - DestinationCidrBlock: 0.0.0.0/0
        GatewayId: !Ref GoodwordInternetGateway
      - DestinationCidrBlock: 172.22.0.0/16
        VpcPeeringConnectionId: !Ref OperationsToGoodwordPeering
```

### Phase 3: Snowflake Configuration

#### 3.1 Snowflake Private Connectivity Setup

**Steps:**
1. **Connect to Snowflake** via Tailscale (through access server at `3.136.236.15`)
2. **Navigate to Admin → Security → Private Connectivity**
3. **Create private connection** to Operations VPC
4. **Specify VPC details**:
   - VPC ID: `vpc-0f0a0744e35746a67`
   - Subnet: `subnet-0237c9503debf76c3` (ops-private-subnet)
   - Security Group: `sg-0bb9c59bf7f51d068` (ops-sqlmesh-server-sg)

#### 3.2 Snowflake Configuration Details

**Connection Parameters:**
- **VPC ID**: `vpc-0f0a0744e35746a67`
- **Subnet ID**: `subnet-0237c9503debf76c3`
- **Security Group**: `sg-0bb9c59bf7f51d068`
- **Region**: `us-east-2`
- **Service**: `com.amazonaws.us-east-2.execute-api`

### Phase 4: Testing & Validation

#### 4.1 Connectivity Test

```bash
# Test from access server (via Tailscale)
curl -k https://172.22.2.106:443/health

# Test from Snowflake
SELECT sqlmesh_query('SELECT 1');
```

### Phase 5: Snowflake Security Lockdown (FINAL PHASE)

#### 5.1 Current Security Risk
- **Current State**: Snowflake is open to the world (0.0.0.0/0 access)
- **Security Risk**: High - any internet user can potentially access Snowflake
- **Target State**: Private connectivity only through VPC endpoint

#### 5.2 Pre-Lockdown Checklist

**⚠️ CRITICAL: Complete these checks before locking down Snowflake:**

1. **Identify Airbyte IP Ranges:**
   ```bash
   # Find Airbyte server IP addresses
   # Check where Airbyte is hosted (AWS, GCP, Azure, on-premises)
   # Document all IP ranges that need access
   ```

2. **Test Current Airbyte Connections:**
   ```bash
   # Verify all Airbyte Snowflake connectors are working
   # Run test syncs to ensure connectivity
   # Document any issues before lockdown
   ```

3. **Verify Tailscale Network:**
   ```bash
   # Confirm Tailscale network range (usually 100.64.0.0/10)
   # Test Tailscale connectivity to Snowflake
   # Ensure access server can reach Snowflake
   ```

4. **Document Current Access:**
   ```bash
   # List all systems that currently access Snowflake
   # Verify IP ranges for each system
   # Create access matrix before lockdown
   ```

#### 5.3 Snowflake Security Configuration

**Steps to Lock Down Snowflake:**
1. **Connect to Snowflake** using SnowSQL:
   ```bash
   /opt/homebrew/bin/snow sql -a your-account -u your-user
   ```

2. **Navigate to Admin → Security → Network Policies**
3. **Create Network Policy** to restrict access:
```sql
-- Create network policy to restrict access
-- ALLOWED: Operations VPC, Goodword VPC, Tailscale, Airbyte Cloud US IPs
CREATE OR REPLACE NETWORK POLICY snowflake_private_access
ALLOWED_IP_LIST = (
  '172.22.0.0/16',  -- Operations VPC
  '172.20.0.0/16',  -- Goodword VPC  
  '100.64.0.0/10',  -- Tailscale network range
  '10.0.0.0/8',     -- Private networks
  '172.16.0.0/12',  -- Private networks
  '192.168.0.0/16', -- Private networks
  -- Airbyte Cloud US IP addresses (from https://docs.airbyte.com/platform/1.7/operating-airbyte/ip-allowlist)
  '34.106.109.131', -- Airbyte Cloud GCP US West 3
  '34.106.196.165', -- Airbyte Cloud GCP US West 3
  '34.106.60.246',  -- Airbyte Cloud GCP US West 3
  '34.106.229.69',  -- Airbyte Cloud GCP US West 3
  '34.106.127.139', -- Airbyte Cloud GCP US West 3
  '34.106.218.58',  -- Airbyte Cloud GCP US West 3
  '34.106.115.240', -- Airbyte Cloud GCP US West 3
  '34.106.225.141', -- Airbyte Cloud GCP US West 3
  '34.33.7.0/29'    -- Airbyte Cloud GCP US Central 1
)
BLOCKED_IP_LIST = ('0.0.0.0/0')
COMMENT = 'Restrict Snowflake access to private VPCs, Tailscale, and specific Airbyte Cloud US IPs';
```

4. **Apply Network Policy** to account:
   ```sql
   -- Apply network policy to account
   ALTER ACCOUNT SET NETWORK_POLICY = snowflake_private_access;
   ```

#### 5.3 Critical Access Requirements

**Must Maintain Access For:**
1. **Tailscale Network** (`100.64.0.0/10`)
   - Remote access for development and administration
   - Access server connectivity
   - Management and monitoring

2. **Airbyte Network** (Private IP ranges)
   - Data pipeline operations
   - Regular data sync operations
   - ETL processes

3. **Operations VPC** (`172.22.0.0/16`)
   - SQLMesh server access
   - VPC endpoint connectivity

4. **Goodword VPC** (`172.20.0.0/16`)
   - Production data access
   - Cross-VPC operations

#### 5.4 Validation of Security Lockdown

**Test External Access (Should Fail):**
```bash
# This should fail after lockdown
curl -k https://your-snowflake-account.snowflakecomputing.com
```

**Test Internal Access (Should Work):**
```bash
# This should work from VPC endpoint
/opt/homebrew/bin/snow sql -a your-account -u your-user

# This should work from Tailscale network
/opt/homebrew/bin/snow sql -a your-account -u your-user

# This should work from Airbyte
# (Test your Airbyte connections)
```

**Test Airbyte Connectivity:**
```bash
# Verify Airbyte can still connect to Snowflake
# Check your Airbyte Snowflake connectors
# Ensure data pipelines continue to work
```

#### 5.4 Rollback Plan (If Needed)

**Emergency Rollback:**
```sql
-- Remove network policy to restore world access (EMERGENCY ONLY)
ALTER ACCOUNT UNSET NETWORK_POLICY;
```

**⚠️ WARNING**: Only use rollback in emergency situations as it reopens Snowflake to the world.

#### 4.2 Network Flow Validation

```
Your Local Machine (Tailscale) 
    ↓
Tailscale Network
    ↓
Access Server (3.136.236.15)
    ↓
Operations VPC (172.22.0.0/16)
    ↓
Private Subnet (172.22.2.0/24)
    ↓
SQLMesh Server (172.22.2.106)
    ↓
VPC Endpoint (172.22.2.100)
    ↓
Snowflake (Private Connectivity)
```

## Security Considerations

### 1. Network Security
- **Private subnets only** for SQLMesh server
- **No public IP addresses** for sensitive components
- **Security groups** restrict access to specific IP ranges
- **VPC peering** for controlled cross-VPC communication

### 2. Access Control
- **Tailscale integration** for secure remote access
- **IAM roles** instead of access keys
- **Encryption in transit** (TLS/SSL)
- **Private connectivity** for Snowflake

### 3. Monitoring
- **CloudWatch logs** for VPC endpoint
- **CloudWatch metrics** for SQLMesh server
- **Security group monitoring**
- **Network flow logs**

## Cost Analysis

### Current Costs
- **Operations VPC**: Existing infrastructure
- **Goodword VPC**: Existing infrastructure
- **SQLMesh Server**: t3.medium (~$30/month)

### Additional Costs
| Component | Monthly Cost |
|-----------|-------------|
| **VPC Endpoint** | $7.50 |
| **Data Transfer** | $0 (private network) |
| **Snowflake Private Connectivity** | $0 |
| **Total Additional** | **$7.50/month** |

### Cost Optimization
- **Single VPC endpoint** for all environments
- **Shared infrastructure** costs
- **No data transfer charges** (private network)
- **Efficient resource utilization**

## Implementation Steps

### Step 1: Update CloudFormation Templates
```bash
# Update operations-vpc stack
aws cloudformation update-stack \
  --stack-name ops-vpc-networking \
  --template-body file://networking/vpc-subnets.yml \
  --capabilities CAPABILITY_IAM
```

### Step 2: Configure Snowflake Private Connectivity
```bash
# Connect via Tailscale
tailscale up

# Access Snowflake
snowsql -a your-account -u your-user

# Navigate to Admin → Security → Private Connectivity
# Create new private connection
# Specify VPC details
```

### Step 3: Test Connectivity
```bash
# Test from access server
curl -k https://172.22.2.106:443/health

# Test from Snowflake
SELECT sqlmesh_query('SELECT 1');
```

### Step 4: Monitor and Validate
```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints --region us-east-2

# Check security groups
aws ec2 describe-security-groups --region us-east-2

# Monitor CloudWatch logs
aws logs describe-log-groups --region us-east-2
```

## Troubleshooting

### Common Issues

#### 1. VPC Endpoint Not Accessible
- **Check security groups** for proper ingress rules
- **Verify subnet associations** for VPC endpoint
- **Confirm private DNS** is enabled

#### 2. Snowflake Connection Issues
- **Verify VPC peering** is established
- **Check route tables** for proper routing
- **Confirm security groups** allow Snowflake access

#### 3. Network Connectivity
- **Test from access server** via Tailscale
- **Verify SQLMesh server** is running
- **Check CloudWatch logs** for errors

### Debug Commands

```bash
# Check VPC endpoint status
aws ec2 describe-vpc-endpoints --region us-east-2

# Check security groups
aws ec2 describe-security-groups --region us-east-2

# Check route tables
aws ec2 describe-route-tables --region us-east-2

# Check VPC peering
aws ec2 describe-vpc-peering-connections --region us-east-2
```

## Next Steps

1. **Review and approve** this plan
2. **Update CloudFormation templates** with VPC endpoint configuration
3. **Deploy VPC endpoint** in Operations VPC
4. **Configure Snowflake private connectivity**
5. **Test and validate** connectivity
6. **Monitor and optimize** performance

## Contact Information

- **Primary Contact**: [Your Name]
- **AWS Account**: 058264125918
- **Region**: us-east-2
- **Last Updated**: [Current Date]

---

**Note**: This document should be updated as the implementation progresses and any changes are made to the infrastructure.

# DNS Configuration for goodword.cloud

This directory contains the comprehensive DNS configuration for the goodword.cloud domain, including both public and private zones.

## Structure

- `domains.yml` - Main CloudFormation template with all DNS records
- `deploy-dns.sh` - Deployment script
- `README.md` - This documentation

## DNS Zones

### Public Zone (goodword.cloud)
Publicly accessible endpoints:

- `api.goodword.cloud` → AWS App Runner API
- `data-operations-db.goodword.cloud` → RDS Aurora cluster
- `db.goodword.cloud` → Main RDS database
- `klavitron.goodword.cloud` → API Gateway service
- `klavitron-202508141805.us-east-2.goodword.cloud` → Specific deployment

### Private Zone (internal.goodword.cloud)
Private endpoints accessible via Tailscale VPN:

- `sqlmesh.internal.goodword.cloud` → SQLMesh server (172.22.2.106)
- `postgres.internal.goodword.cloud` → SQLMesh PostgreSQL (172.22.4.203)
- `operations.internal.goodword.cloud` → Operations host (172.22.1.10)
- `*.internal.goodword.cloud` → Wildcard CNAME for convenience

## Deployment

### Prerequisites
- AWS CLI configured
- Appropriate IAM permissions
- VPC with name "ops-vpc" exists

### Deploy DNS Configuration

```bash
# From the operations-vpc directory
./deploy-dns.sh
```

### Manual Deployment

```bash
aws cloudformation deploy \
  --template-file dns/domains.yml \
  --stack-name goodword-dns \
  --region us-east-2 \
  --parameter-overrides \
    VpcId=vpc-xxxxxxxxx \
    Environment=ops \
    PublicHostedZoneId=Z04032891ZM6L7J3T40M7 \
  --capabilities CAPABILITY_IAM
```

## Usage

### For Engineers on Tailscale

Access internal services using friendly names:

```bash
# SSH to SQLMesh server
ssh -i ~/.ssh/ops-vpc-key.pem ec2-user@sqlmesh.internal.goodword.cloud

# Access SQLMesh UI
http://sqlmesh.internal.goodword.cloud:8000

# Connect to PostgreSQL
psql -h postgres.internal.goodword.cloud -U postgres -d sqlmesh_data
```

### For Public Services

Public services remain accessible as before:

```bash
# API endpoint
curl https://api.goodword.cloud/health

# Database connections (if publicly accessible)
psql -h db.goodword.cloud -U username -d database
```

## Adding New Services

### Public Service
Add to the "PUBLIC DNS RECORDS" section in `domains.yml`:

```yaml
NewServiceRecord:
  Type: AWS::Route53::RecordSet
  Properties:
    HostedZoneId: !Ref PublicHostedZoneId
    Name: newservice.goodword.cloud
    Type: CNAME
    TTL: 60
    ResourceRecords:
      - target.example.com
```

### Private Service
Add to the "PRIVATE DNS RECORDS" section in `domains.yml`:

```yaml
NewPrivateServiceRecord:
  Type: AWS::Route53::RecordSet
  Properties:
    HostedZoneId: !Ref PrivateHostedZone
    Name: newservice.internal.goodword.cloud
    Type: A
    TTL: 300
    ResourceRecords:
      - 172.22.x.x
```

## IP Address Management

### Current Private IPs
- SQLMesh Server: `172.22.2.106`
- PostgreSQL: `172.22.4.203`
- Operations Host: `172.22.1.10` (update if different)

### Updating IPs
When server IPs change, update the `ResourceRecords` in `domains.yml` and redeploy:

```bash
./deploy-dns.sh
```

## Troubleshooting

### Check DNS Resolution
```bash
# From a machine on Tailscale
nslookup sqlmesh.internal.goodword.cloud
dig sqlmesh.internal.goodword.cloud

# From within the VPC
nslookup sqlmesh.internal.goodword.cloud 172.22.0.2
```

### Verify CloudFormation Stack
```bash
aws cloudformation describe-stacks --stack-name goodword-dns --region us-east-2
```

### Check Route 53 Records
```bash
# List all records in private zone
aws route53 list-resource-record-sets --hosted-zone-id $(aws route53 list-hosted-zones --query 'HostedZones[?Name==`internal.goodword.cloud.`].Id' --output text --region us-east-2) --region us-east-2
```

## Security Notes

- Private zone is only resolvable from within the VPC and connected Tailscale devices
- Public zone records are publicly resolvable
- All private services should have appropriate security groups
- Consider using Route 53 Resolver for more complex DNS scenarios

## Cost

- Public hosted zone: $0.50/month (already exists)
- Private hosted zone: $0.50/month
- DNS queries: $0.40 per million queries
- Total additional cost: ~$0.50/month for private zone

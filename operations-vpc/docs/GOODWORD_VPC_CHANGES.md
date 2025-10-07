# Goodword VPC Changes for Snowflake Integration

## Overview
This document tracks changes made to the Goodword VPC to enable Snowflake integration through the Operations VPC.

## Changes Made

### 1. VPC Peering Routes Added
**Date**: 2025-10-05  
**Purpose**: Enable bidirectional communication between Operations VPC and Goodword VPC

**Routes Added**:
- **Route Table**: `rtb-00c1502d794b52291` (goodwordvpc-rtb-private3-us-east-2a)
- **Destination**: `172.22.0.0/16` (Operations VPC)
- **Target**: VPC Peering Connection `pcx-093256f9adcfae896`

### 2. Security Group Rules Added
**Date**: 2025-10-05  
**Purpose**: Enable cross-VPC communication for testing and Snowflake integration

**Security Group Changes**:
- **Security Group**: `sg-0d8c74a9cdf463253` (VPN mesh server)
- **Added Rules**:
  - ICMP from Operations VPC (172.22.0.0/16)
  - TCP 1-65535 from Operations VPC (172.22.0.0/16) 
  - UDP 1-65535 from Operations VPC (172.22.0.0/16)

**Additional Route Tables to Update**:
- `rtb-00f1620387a847e15` (goodwordvpc-rtb-private2-us-east-2b)
- `rtb-018af0c33a6b7d67d` (goodwordvpc-rtb-public)
- `rtb-0b76d032cd2261d89` (goodwordvpc-rtb-private1-us-east-2a)
- `rtb-0119076d868780a1a` (goodwordvpc-rtb-private4-us-east-2b)

## CloudFormation Template for Goodword VPC

The following CloudFormation template should be added to the Goodword VPC repository to make these changes permanent:

```yaml
# Add this to your Goodword VPC CloudFormation template
# This enables bidirectional VPC peering with Operations VPC

Resources:
  # Route to Operations VPC for private subnets
  OperationsVpcRoutePrivate1:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable1  # Replace with actual reference
      DestinationCidrBlock: 172.22.0.0/16
      VpcPeeringConnectionId: pcx-093256f9adcfae896

  OperationsVpcRoutePrivate2:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable2  # Replace with actual reference
      DestinationCidrBlock: 172.22.0.0/16
      VpcPeeringConnectionId: pcx-093256f9adcfae896

  OperationsVpcRoutePrivate3:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable3  # Replace with actual reference
      DestinationCidrBlock: 172.22.0.0/16
      VpcPeeringConnectionId: pcx-093256f9adcfae896

  OperationsVpcRoutePrivate4:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PrivateRouteTable4  # Replace with actual reference
      DestinationCidrBlock: 172.22.0.0/16
      VpcPeeringConnectionId: pcx-093256f9adcfae896

  OperationsVpcRoutePublic:
    Type: AWS::EC2::Route
    Properties:
      RouteTableId: !Ref PublicRouteTable  # Replace with actual reference
      DestinationCidrBlock: 172.22.0.0/16
      VpcPeeringConnectionId: pcx-093256f9adcfae896
```

## Current VPC Peering Status

**Peering Connection**: `pcx-093256f9adcfae896`
- **Status**: Active
- **Operations VPC**: `vpc-0f0a0744e35746a67` (172.22.0.0/16)
- **Goodword VPC**: `vpc-07ee3805f07edfac1` (172.20.0.0/16)

## Testing

**From Operations VPC**:
- Can reach Goodword VPC instances (172.20.0.0/16)
- VPN mesh server: `172.20.0.91`

**From Goodword VPC**:
- Can reach Operations VPC instances (172.22.0.0/16)
- SQLMesh server: `172.22.2.106`
- Access server: `172.22.1.15`

## Next Steps

1. **Immediate**: Complete the remaining route table updates
2. **Repository**: Move the CloudFormation template to Goodword VPC repository
3. **Testing**: Verify bidirectional connectivity
4. **Documentation**: Update Goodword VPC documentation

## Security Considerations

- VPC peering is private and secure
- No internet traffic flows through the peering connection
- Traffic is encrypted within AWS network
- Security groups still control access at the instance level

## Rollback Plan

If needed, remove the routes by deleting them from the route tables:
```bash
aws ec2 delete-route --route-table-id <route-table-id> --destination-cidr-block 172.22.0.0/16 --region us-east-2
```

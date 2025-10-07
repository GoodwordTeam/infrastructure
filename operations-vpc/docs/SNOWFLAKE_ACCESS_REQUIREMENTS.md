# Snowflake Access Requirements

## Critical Access Requirements for Phase 5 (Security Lockdown)

### **Must Maintain Access For:**

#### 1. **Tailscale Network** (`100.64.0.0/10`)
- **Purpose**: Remote access for development and administration
- **Users**: Development team, administrators
- **Access**: Via access server (3.136.236.15)
- **Requirements**: 
  - SnowSQL access for development
  - Management and monitoring access
  - SQLMesh server administration

#### 2. **Airbyte Network** (Cloud-based)
- **Purpose**: Data pipeline operations
- **Systems**: Airbyte Cloud connectors and sync processes
- **Requirements**:
  - Regular data sync operations
  - ETL processes
  - Data pipeline monitoring
- **✅ RESOLVED**: Airbyte Cloud US IP addresses identified
- **Source**: [Airbyte IP Allowlist Documentation](https://docs.airbyte.com/platform/1.7/operating-airbyte/ip-allowlist)

#### 3. **Operations VPC** (`172.22.0.0/16`)
- **Purpose**: SQLMesh server and VPC endpoint access
- **Systems**: 
  - SQLMesh server (172.22.2.106)
  - VPC endpoint for private connectivity
- **Requirements**:
  - SQLMesh server connectivity
  - VPC endpoint access
  - Cross-VPC operations

#### 4. **Goodword VPC** (`172.20.0.0/16`)
- **Purpose**: Production data access
- **Systems**: Production applications and services
- **Requirements**:
  - Production data access
  - Cross-VPC operations
  - Production monitoring

### **Pre-Lockdown Checklist**

#### **Step 1: Identify Airbyte IP Ranges**
```bash
# For Airbyte Cloud: No specific IP ranges published
# Solution: Use private network ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
# For self-hosted Airbyte: Find your Airbyte server IP addresses
# Check where Airbyte is hosted (AWS, GCP, Azure, on-premises)
# Document all IP ranges that need access
```

#### **Step 2: Test Current Airbyte Connections**
```bash
# Verify all Airbyte Snowflake connectors are working
# Run test syncs to ensure connectivity
# Document any issues before lockdown
```

#### **Step 3: Verify Tailscale Network**
```bash
# Confirm Tailscale network range (usually 100.64.0.0/10)
# Test Tailscale connectivity to Snowflake
# Ensure access server can reach Snowflake
```

#### **Step 4: Document Current Access**
```bash
# List all systems that currently access Snowflake
# Verify IP ranges for each system
# Create access matrix before lockdown
```

### **Network Policy Configuration**

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

### **Validation Tests**

#### **Test External Access (Should Fail):**
```bash
# This should fail after lockdown
curl -k https://your-snowflake-account.snowflakecomputing.com
```

#### **Test Internal Access (Should Work):**
```bash
# This should work from VPC endpoint
/opt/homebrew/bin/snow sql -a your-account -u your-user

# This should work from Tailscale network
/opt/homebrew/bin/snow sql -a your-account -u your-user

# This should work from Airbyte
# (Test your Airbyte connections)
```

#### **Test Airbyte Connectivity:**
```bash
# Verify Airbyte can still connect to Snowflake
# Check your Airbyte Snowflake connectors
# Ensure data pipelines continue to work
```

### **Emergency Rollback**

If Airbyte or Tailscale access is broken:

```sql
-- Remove network policy to restore world access (EMERGENCY ONLY)
ALTER ACCOUNT UNSET NETWORK_POLICY;
```

**⚠️ WARNING**: Only use rollback in emergency situations as it reopens Snowflake to the world.

### **Next Steps**

1. **Complete pre-lockdown checklist** before implementing Phase 5
2. **Identify exact Airbyte IP ranges** 
3. **Test all current connections** to ensure they work
4. **Implement network policy** with all required IP ranges
5. **Validate all access** after lockdown
6. **Monitor for any issues** and be ready to rollback if needed

---

**Note**: This document should be updated as we identify the exact IP ranges for Airbyte and any other systems that need access to Snowflake.

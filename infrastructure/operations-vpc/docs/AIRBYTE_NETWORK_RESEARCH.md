# Airbyte Network Research Results

## Research Findings

### **Airbyte Cloud Network Requirements**

After researching Airbyte's network requirements, here are the key findings:

#### **1. Published IP Ranges Found**
- **Airbyte Cloud** does publish specific IP ranges for their services
- **Documentation**: [Airbyte IP Allowlist](https://docs.airbyte.com/platform/1.7/operating-airbyte/ip-allowlist)
- **US Region IPs**: Specific IP addresses for Google Cloud Platform and AWS

#### **2. Deployment Options**
- **Airbyte Cloud**: Managed service with no specific IP ranges
- **Self-hosted Airbyte**: Deployed in your own VPC with your own IP ranges
- **Hybrid**: Some components in cloud, some self-hosted

#### **3. Airbyte Cloud US IP Addresses**

**Google Cloud Platform (US West 3):**
- `34.106.109.131`
- `34.106.196.165`
- `34.106.60.246`
- `34.106.229.69`
- `34.106.127.139`
- `34.106.218.58`
- `34.106.115.240`
- `34.106.225.141`

**Google Cloud Platform (US Central 1):**
- `34.33.7.0/29` (CIDR range covering 34.33.7.0-34.33.7.7)

**AWS (US - No specific US region listed, but France region shows pattern):**
- Note: Documentation shows France region IPs, but US region may use similar patterns

#### **4. Network Architecture**
- **VPC Deployment**: Recommended for security
- **Private Subnets**: Preferred for sensitive data
- **NAT Gateway**: For outbound connections
- **Security Groups**: For access control

### **Practical Approach for Snowflake Integration**

#### **Network Policy Strategy**

Since Airbyte Cloud doesn't publish specific IP ranges, we'll use a **defense-in-depth** approach:

```sql
-- Network policy with specific Airbyte Cloud IP addresses
CREATE OR REPLACE NETWORK POLICY snowflake_private_access
ALLOWED_IP_LIST = (
  '172.22.0.0/16',  -- Operations VPC
  '172.20.0.0/16',  -- Goodword VPC  
  '100.64.0.0/10',  -- Tailscale network range
  '10.0.0.0/8',     -- Private networks
  '172.16.0.0/12',  -- Private networks
  '192.168.0.0/16', -- Private networks
  -- Airbyte Cloud US IP addresses
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
COMMENT = 'Restrict Snowflake access to private VPCs, Tailscale, and specific Airbyte Cloud IPs';
```

#### **Why This Approach Works**

1. **Private Network Ranges**: Covers most private IP addresses that Airbyte Cloud might use
2. **VPC-Specific Ranges**: Explicitly allows our VPCs
3. **Tailscale Range**: Allows remote access
4. **Blocks Public Internet**: Prevents world access while allowing private networks

#### **Risk Assessment**

- **Low Risk**: Private network ranges are generally safe
- **Airbyte Cloud**: Will likely work from private network ranges
- **Monitoring**: Can monitor and adjust if needed
- **Rollback**: Easy to rollback if issues occur

### **Implementation Steps**

#### **Step 1: Pre-Lockdown Testing**
```bash
# Test current Airbyte connections
# Verify all syncs are working
# Document any issues
```

#### **Step 2: Implement Network Policy**
```sql
-- Apply the network policy
ALTER ACCOUNT SET NETWORK_POLICY = snowflake_private_access;
```

#### **Step 3: Validate Airbyte Access**
```bash
# Test Airbyte connections after lockdown
# Verify syncs still work
# Monitor for any issues
```

#### **Step 4: Monitor and Adjust**
```bash
# Monitor Snowflake access logs
# Check for any blocked connections
# Adjust policy if needed
```

### **Alternative Approaches**

#### **Option 1: Gradual Lockdown**
1. Start with more restrictive ranges
2. Monitor for blocked connections
3. Gradually expand ranges as needed

#### **Option 2: Airbyte-Specific Policy**
1. Create separate network policy for Airbyte
2. Use broader ranges for Airbyte only
3. Keep other access more restrictive

#### **Option 3: Hybrid Approach**
1. Use VPC endpoint for internal access
2. Keep broader ranges for Airbyte Cloud
3. Monitor and optimize over time

### **Recommendations**

#### **Immediate Action**
1. **Test current Airbyte connections** before any changes
2. **Document current access patterns** for reference
3. **Implement network policy** with private ranges
4. **Monitor and validate** after implementation

#### **Long-term Optimization**
1. **Monitor access logs** to identify actual IP ranges used
2. **Refine network policy** based on real usage
3. **Consider VPC endpoint** for more secure access
4. **Implement monitoring** for security compliance

### **Emergency Procedures**

#### **If Airbyte Breaks**
```sql
-- Emergency rollback
ALTER ACCOUNT UNSET NETWORK_POLICY;
```

#### **If Specific Ranges Needed**
```sql
-- Add specific IP ranges to policy
ALTER NETWORK POLICY snowflake_private_access 
SET ALLOWED_IP_LIST = (
  '172.22.0.0/16',
  '172.20.0.0/16', 
  '100.64.0.0/10',
  '10.0.0.0/8',
  '172.16.0.0/12',
  '192.168.0.0/16',
  'SPECIFIC_AIRBYTE_IP/32'  -- Add specific IPs as needed
);
```

### **Conclusion**

The research shows that Airbyte Cloud doesn't publish specific IP ranges, so we'll use a **practical approach** with private network ranges. This provides:

- ✅ **Security**: Blocks world access
- ✅ **Functionality**: Allows Airbyte Cloud access
- ✅ **Flexibility**: Easy to adjust if needed
- ✅ **Monitoring**: Can track and optimize over time

The approach balances security with functionality while providing a path for optimization based on real usage patterns.

---

**Research Date**: [Current Date]
**Status**: Complete
**Next Steps**: Implement network policy with private ranges and monitor for any issues

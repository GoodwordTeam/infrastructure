# CRITICAL: Tailscale Routing Configuration

## Overview
The Operations Host **MUST** advertise the `/13` network (`172.16.0.0/13`) to enable routing to ALL VPCs in the operations space.

## Why /13 is Critical

### Network Range Coverage
- **172.16.0.0/13** covers: `172.16.0.0` to `172.23.255.255`
- This includes **ALL** VPCs we plan to build in the operations space
- **DO NOT** advertise smaller routes like `/16` or `/20` - this breaks routing to other VPCs

### Current VPCs Covered
- **Operations VPC**: `172.22.0.0/16` (172.22.0.0 to 172.22.255.255)
- **GoodWord VPC**: `172.20.0.0/16` (172.20.0.0 to 172.20.255.255)
- **Future VPCs**: Any VPC in the 172.16.0.0/13 range

## Configuration

### Operations Host Tailscale Command
```bash
tailscale up --advertise-routes=172.16.0.0/13 --accept-routes
```

### What This Enables
1. **Local Machine** → **Deimos (Tailscale)** → **Operations Host (Tailscale)**
2. **Operations Host** acts as NAT gateway for ALL VPC traffic
3. **All VPCs** in the 172.16.0.0/13 range are accessible via Tailscale

## Traffic Flow
```
Local Machine (via Tailscale) → Operations Host → NAT → VPC Resources
```

## Security Groups
The Operations Host security group allows:
- **ICMP**: `172.22.0.0/16` (VPC access)
- **TCP**: `172.22.0.0/16` (VPC access)  
- **UDP**: `172.22.0.0/16` (VPC access)

## NAT Configuration
- **Source/Destination Check**: Disabled (required for NAT)
- **IP Forwarding**: Enabled
- **MASQUERADE**: All traffic from Tailscale range (100.64.0.0/10)

## Troubleshooting
If routing stops working:
1. Check if `/13` route is still advertised: `tailscale status --json | jq '.Self.AllowedIPs'`
2. Verify route approval in Tailscale admin console
3. Ensure Operations Host can ping target VPC resources directly
4. Check security groups allow traffic from Operations Host

## Future VPCs
When adding new VPCs:
- **DO NOT** change the `/13` advertisement
- **DO NOT** add smaller route advertisements
- The `/13` route automatically covers all new VPCs in the range
- Just ensure security groups allow traffic from Operations Host


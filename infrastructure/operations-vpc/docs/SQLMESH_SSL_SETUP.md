# SQLMesh Server with Nginx and SSL Setup

## 🎯 Overview

This document describes the implementation of Nginx reverse proxy with SSL termination for the SQLMesh server, providing secure HTTPS access to the SQLMesh web UI.

## 🏗️ Architecture

```
Internet → Nginx (Port 443/HTTPS) → SQLMesh (Port 8000)
         ↓
    Let's Encrypt SSL Certificate
```

## 📋 Changes Made

### 1. SQLMesh Server Configuration (`applications/sqlmesh-server.yml`)

#### Added Packages:
- **Nginx**: Reverse proxy server
- **Certbot**: SSL certificate management
- **python3-certbot-nginx**: Nginx integration for Certbot

#### Nginx Configuration:
- **HTTP Server (Port 80)**: Redirects to HTTPS, handles Let's Encrypt challenges
- **HTTPS Server (Port 443)**: SSL termination, proxies to SQLMesh on port 8000
- **Security Headers**: HSTS, XSS protection, content type sniffing protection
- **WebSocket Support**: For real-time SQLMesh UI features
- **Health Check Endpoint**: `/health` for monitoring

#### SSL Certificate Management:
- **Automatic Certificate**: Let's Encrypt certificate for `sqlmesh.internal.goodword.cloud`
- **Auto-Renewal**: Cron job for certificate renewal
- **Email**: `admin@goodword.cloud` for certificate notifications

### 2. Security Group Updates (`networking/security-endpoints.yml`)

#### Added Inbound Rules:
- **Port 80**: HTTP traffic for Let's Encrypt challenges (0.0.0.0/0)
- **Port 443**: HTTPS traffic for SQLMesh UI (0.0.0.0/0)

#### Existing Rules Preserved:
- **Port 22**: SSH from Access Server
- **Port 8000**: Direct SQLMesh access from Access Server

### 3. CloudWatch Logging

#### Added Log Streams:
- **Nginx Access Logs**: `/var/log/nginx/access.log`
- **Nginx Error Logs**: `/var/log/nginx/error.log`

### 4. Outputs

#### New CloudFormation Outputs:
- **SqlmeshServerHTTPSUrl**: `https://sqlmesh.internal.goodword.cloud`
- **SqlmeshServerHTTPUrl**: `http://sqlmesh.internal.goodword.cloud` (redirects to HTTPS)

## 🚀 Deployment

### Prerequisites:
1. DNS records for `sqlmesh.internal.goodword.cloud` must be configured
2. Security groups must be updated to allow ports 80 and 443
3. AWS Secrets Manager must contain database and Snowflake credentials

### Deployment Command:
```bash
./scripts/deploy-sqlmesh-with-ssl.sh
```

### What the Script Does:
1. **Retrieves Credentials**: From AWS Secrets Manager
2. **Deploys Stack**: Updates CloudFormation stack with new configuration
3. **Waits for Services**: SQLMesh and Nginx to start
4. **Tests Endpoints**: HTTP redirect, HTTPS access, health check
5. **Provides Summary**: Access URLs and monitoring information

## 🔧 Configuration Details

### Nginx Configuration Features:

#### SSL/TLS:
- **Protocols**: TLSv1.2, TLSv1.3
- **Ciphers**: Modern, secure cipher suites
- **Session Caching**: 10-minute session cache
- **HSTS**: 1-year strict transport security

#### Proxy Settings:
- **Headers**: Real IP, forwarded headers for proper client identification
- **Timeouts**: 60-second timeouts for connect, send, and read
- **WebSocket**: Full WebSocket support for real-time features

#### Security Headers:
- **X-Frame-Options**: DENY (prevents clickjacking)
- **X-Content-Type-Options**: nosniff (prevents MIME sniffing)
- **X-XSS-Protection**: 1; mode=block (XSS protection)
- **Strict-Transport-Security**: 1-year HSTS with subdomains

## 🌐 Access URLs

### Primary Access:
- **HTTPS**: `https://sqlmesh.internal.goodword.cloud`
- **HTTP**: `http://sqlmesh.internal.goodword.cloud` (redirects to HTTPS)

### Monitoring:
- **Health Check**: `https://sqlmesh.internal.goodword.cloud/health`
- **CloudWatch Logs**: `/aws/ec2/ops-sqlmesh-server`

## 🔒 Security Considerations

### SSL Certificate:
- **Provider**: Let's Encrypt (free, trusted CA)
- **Auto-Renewal**: Daily cron job checks for renewal
- **Domain**: `sqlmesh.internal.goodword.cloud`
- **Validity**: 90 days (auto-renewed)

### Network Security:
- **HTTPS Only**: All traffic encrypted in transit
- **Private IPs**: Server uses private IPs for obscurity
- **Security Groups**: Restrictive access rules
- **VPC**: Isolated in private subnet

### Application Security:
- **Headers**: Security headers prevent common attacks
- **Proxy**: Nginx handles SSL termination, SQLMesh runs on localhost
- **Logging**: Comprehensive access and error logging

## 🐛 Troubleshooting

### Common Issues:

#### SSL Certificate Issues:
```bash
# Check certificate status
sudo certbot certificates

# Renew certificate manually
sudo certbot renew --dry-run

# Check Nginx configuration
sudo nginx -t
```

#### Service Status:
```bash
# Check SQLMesh container
docker ps
docker logs sqlmesh

# Check Nginx status
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

#### DNS Issues:
```bash
# Test DNS resolution
nslookup sqlmesh.internal.goodword.cloud
dig sqlmesh.internal.goodword.cloud
```

### Log Locations:
- **Nginx Access**: `/var/log/nginx/access.log`
- **Nginx Error**: `/var/log/nginx/error.log`
- **SQLMesh**: Docker logs via `docker logs sqlmesh`
- **CloudWatch**: `/aws/ec2/ops-sqlmesh-server`

## 📊 Monitoring

### Health Checks:
- **Endpoint**: `https://sqlmesh.internal.goodword.cloud/health`
- **Response**: `200 OK` with "healthy" body
- **Use Case**: Load balancer health checks, monitoring systems

### CloudWatch Metrics:
- **EC2 Metrics**: CPU, memory, disk usage
- **Custom Logs**: Nginx access/error logs, SQLMesh logs
- **Alarms**: Can be configured for error rates, response times

## 🔄 Maintenance

### Certificate Renewal:
- **Automatic**: Daily cron job checks and renews if needed
- **Manual**: `sudo certbot renew`
- **Monitoring**: Check renewal status in CloudWatch logs

### Updates:
- **Nginx**: `sudo dnf update nginx`
- **Certbot**: `sudo dnf update certbot`
- **SQLMesh**: Update Docker image and restart container

### Backup:
- **Configuration**: Nginx config in CloudFormation
- **Certificates**: Stored in `/etc/letsencrypt/`
- **Logs**: CloudWatch retention (14 days)

## 🎉 Benefits

1. **Security**: HTTPS encryption for all traffic
2. **Standards**: Standard web ports (80/443)
3. **Performance**: Nginx handles SSL termination efficiently
4. **Monitoring**: Comprehensive logging and health checks
5. **Automation**: Automatic certificate renewal
6. **Flexibility**: Easy to add authentication, rate limiting, etc.
7. **Compliance**: Meets security standards for production use

## 📝 Next Steps

1. **Deploy**: Run the deployment script
2. **Test**: Verify HTTPS access and SSL certificate
3. **Monitor**: Check CloudWatch logs for any issues
4. **Document**: Update team documentation with new URLs
5. **Backup**: Ensure certificate backup strategy is in place

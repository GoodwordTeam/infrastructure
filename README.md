# GoodWord Infrastructure

This repository contains the infrastructure as code for GoodWord's cloud infrastructure.

## 📁 **Repository Structure**

```
infrastructure/
└── operations-vpc/          # Operations VPC Infrastructure
    ├── applications/        # EC2 instances and applications
    ├── networking/          # VPC, subnets, security groups
    ├── data/               # Database infrastructure
    ├── database/           # Database schemas and configurations
    ├── docs/               # Comprehensive documentation
    ├── scripts/            # Deployment and management scripts
    └── README.md           # Operations VPC documentation
```

## 🚀 **Quick Start**

### **Operations VPC**
```bash
cd infrastructure/operations-vpc
./scripts/deploy.sh --status
```

See `infrastructure/operations-vpc/README.md` for detailed documentation.

## 📋 **Infrastructure Components**

### **Operations VPC**
- **Purpose**: Data operations and SQLMesh infrastructure
- **VPC**: `vpc-0f0a0744e35746a67` (172.22.0.0/16) in us-east-2
- **Status**: Fully deployed and operational
- **Documentation**: See `infrastructure/operations-vpc/docs/`

## 🔧 **Management**

### **Deployment**
```bash
# Check status
./scripts/deploy.sh --status

# Deploy all
./scripts/deploy.sh --all

# Deploy specific layer
./scripts/deploy.sh --networking
```

### **Documentation**
- **Architecture**: `infrastructure/operations-vpc/docs/ARCHITECTURE_DIAGRAM.md`
- **Integration**: `infrastructure/operations-vpc/docs/SNOWFLAKE_SQLMESH_HANDOFF.md`
- **Resume Guide**: `infrastructure/operations-vpc/docs/CONVERSATION_RESUME_GUIDE.md`

## 📞 **Support**

For infrastructure issues, see the documentation in each component's directory.

---

**Repository**: GoodWord Infrastructure  
**Last Updated**: 2025-10-05  
**Status**: Active Development

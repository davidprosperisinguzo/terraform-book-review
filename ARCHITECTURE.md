# Terraform Book Review Application - Architecture Documentation

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          INTERNET (0.0.0.0/0)                       │
└────────────────────────────┬────────────────────────────────────────┘
                             │
                   ┌─────────▼────────┐
                   │  Public ALB      │
                   │  (Port 80/443)   │
                   │  eu-west-2a/2b   │
                   └─────────┬────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │                                         │
   ┌────▼────┐ Public Subnet AZ-1             ┌────▼────┐ Public Subnet AZ-2
   │ Web VM 1 │ (10.0.0.0/24)                 │ Web VM 2 │ (10.0.1.0/24)
   │ t3.micro │ sg: web-tier-sg               │ t3.micro │
   │ Ubuntu   │ SSH: terraform-vm key         │ Ubuntu   │
   │ 22.04    │ Route: IGW                    │ 22.04    │
   └────┬────┘                                 └────┬────┘
        │                                         │
        │ NOTE: Currently deploying 1 instance    │
        │ Documentation reflects 2-instance       │
        │ design for scalability reference       │
        │                                        │
        └────────────────┬──────────────────────┘
                         │
                   ┌─────▼──────┐
                   │Internal ALB │
                   │(Port 3001)  │
                   │Private IP   │
                   └─────┬──────┘
        ┌──────────────────┴┐
        │                   │
   ┌────▼────┐ Private      ┌────▼────┐ Private
   │ App VM 1 │ Subnet AZ-1  │ App VM 2 │ Subnet AZ-2
   │ t3.micro │ (10.0.2.0/24)│ t3.micro │ (10.0.3.0/24)
   │ Ubuntu   │ SSH: Via NAT  │ Ubuntu   │ Via Bastion
   │ 22.04    │ Route: NAT   │ 22.04    │
   └────┬────┘              └────┬────┘
        │                        │
        │ NOTE: Currently deploying 1 instance
        │ Documentation reflects 2-instance design
        │
        └────────────┬───────────┘
                     │
              ┌──────▼──────┐
              │ RDS MySQL   │
              │ (Port 3306) │
              │ Private IP  │
              │ db.t3.micro │
              │20GB Storage │
              │ No Backups  │
              └─────────────┘
              Subnets:
              - 10.0.4.0/24 (AZ-1)
              - 10.0.5.0/24 (AZ-2)

VPC CIDR: 10.0.0.0/16
NAT Gateway: 1 per AZ (High Availability)
Availability Zones: eu-west-2a, eu-west-2b
EC2 Key Pair: terraform-vm.pem
```

## Detailed Component Architecture

### 1. Networking Tier (module: `networking`)

**VPC Configuration**
```
VPC: 10.0.0.0/16
├── Public Subnets (Web Tier)
│   ├── eu-west-2a: 10.0.0.0/24 (256 IPs, ~250 usable)
│   └── eu-west-2b: 10.0.1.0/24
├── Private Subnets (App Tier)
│   ├── eu-west-2a: 10.0.2.0/24
│   └── eu-west-2b: 10.0.3.0/24
└── Private Subnets (DB Tier)
    ├── eu-west-2a: 10.0.4.0/24
    └── eu-west-2b: 10.0.5.0/24
```

**Internet Gateway & NAT**
- IGW: Attached to VPC for public internet access
- NAT Gateways: 2 (one per AZ) in public subnets
  - Elastic IPs for stable outbound connections
  - Private subnets route through NAT for patching/updates

**Route Tables**
```
Public Route Table:
├── Destination: 0.0.0.0/0
└── Target: Internet Gateway

Private App Route Table (AZ-1):
├── Destination: 0.0.0.0/0
└── Target: NAT Gateway 1

Private App Route Table (AZ-2):
├── Destination: 0.0.0.0/0
└── Target: NAT Gateway 2

Private DB Route Table:
└── Local routes only (no internet access)
```

### 2. Security Tier (module: `security`)

**Security Group Architecture**

```
Public ALB Security Group (public-alb-sg)
├── Inbound:
│   ├── TCP 80 (HTTP) from 0.0.0.0/0
│   └── TCP 443 (HTTPS) from 0.0.0.0/0
└── Outbound: All traffic (0.0.0.0/0)

Web Tier Security Group (web-tier-sg)
├── Inbound:
│   ├── TCP 80 from public-alb-sg (only from ALB)
│   └── TCP 22 (SSH) from allowed_ssh_cidr
├── Outbound: All traffic
└── Attached to: Web VM instances

Internal ALB Security Group (internal-alb-sg)
├── Inbound:
│   └── TCP 3001 from web-tier-sg
├── Outbound: All traffic
└── Internal: true (private IPv4 only)

App Tier Security Group (app-tier-sg)
├── Inbound:
│   ├── TCP 3001 from internal-alb-sg (ALB)
│   └── TCP 22 from web-tier-sg (SSH from web servers)
├── Outbound: All traffic
└── Attached to: App VM instances

RDS Security Group (rds-sg)
├── Inbound:
│   └── TCP 3306 (MySQL) from app-tier-sg
├── Outbound: All traffic
└── Attached to: RDS instance
```

**Security Group Flow**

```
Internet Traffic Flow:
Internet → (80/443) → Public ALB SG → (80) → Web Tier SG → Web VM
                    
App Tier Traffic Flow:
Web VM → Internal ALB SG → (3001) → App Tier SG → App VM

Database Traffic Flow:
App VM → (3306) → RDS SG → RDS Instance
```

### 3. Public Load Balancer (module: `public_alb`)

**Configuration**
```
Name: bookreview-public-alb
Type: Application Load Balancer
Scheme: internet-facing (public)
IP Address Type: IPv4

Network Configuration:
├── Subnets: Public subnets (eu-west-2a, eu-west-2b)
└── Security Groups: public-alb-sg

Listeners:
└── Listener 1
    ├── Protocol: HTTP
    ├── Port: 80
    └── Default Action: Forward to Target Group

Target Group: bookreview-web-tg
├── Protocol: HTTP
├── Port: 80
├── VPC: VPC ID
├── Target Type: Instance
├── Health Check:
│   ├── Path: /
│   ├── Protocol: HTTP
│   ├── Port: 80
│   ├── Interval: 30 seconds
│   ├── Timeout: 5 seconds
│   ├── Healthy Threshold: 2
│   ├── Unhealthy Threshold: 2
│   └── Matcher: 200-399
└── Registered Targets: Web VM 1, Web VM 2
```

### 4. Web Tier VMs (module: `web_vm`)

**Instance Configuration**
```
Instances: 2 (Design shows 2 for HA, 1 currently deployed)
├── Instance 1
│   ├── AZ: eu-west-2a
│   ├── Subnet: 10.0.0.0/24 (public)
│   ├── Type: t3.micro
│   ├── AMI: Ubuntu 22.04 LTS
│   ├── Root Volume: 20 GB (gp3)
│   ├── Public IP: Assigned (due to public subnet)
│   ├── Security Group: web-tier-sg
│   ├── Key Pair: terraform-vm
   └── Tags: name=bookreview-web-vm-1
└── Instance 2 (Design reference, not deployed)
    └── AZ: eu-west-2b
        └── Similar configuration

Note: No user data scripts are implemented. Manual or other deployment 
tools can be used to install and configure application software.
```

### 5. Internal Load Balancer (module: `internal_alb`)

**Configuration**
```
Name: bookreview-internal-alb
Type: Application Load Balancer
Scheme: internal (private IP only)

Network Configuration:
├── Subnets: Private app subnets (eu-west-2a, eu-west-2b)
└── Security Groups: internal-alb-sg

Listeners:
└── Listener 1
    ├── Protocol: HTTP
    ├── Port: 3001
    └── Default Action: Forward to Target Group

Target Group: bookreview-app-tg
├── Protocol: HTTP
├── Port: 3001
├── Health Check Configuration: (same as public ALB)
└── Registered Targets: App VM 1, App VM 2
```

### 6. App Tier VMs (module: `app_vm`)

**Instance Configuration**
```
Instances: 2 (Design shows 2 for HA, 1 currently deployed)
├── Instance 1
│   ├── AZ: eu-west-2a
│   ├── Subnet: 10.0.2.0/24 (private)
│   ├── Type: t3.micro
│   ├── AMI: Ubuntu 22.04 LTS
│   ├── Root Volume: 20 GB (gp3)
│   ├── Public IP: None (private subnet)
│   ├── Security Group: app-tier-sg
│   ├── Key Pair: terraform-vm
│   └── Internet: NAT Gateway in AZ-1
└── Instance 2 (Design reference, not deployed)
    └── AZ: eu-west-2b
        └── Similar configuration

Note: No user data scripts are implemented. Manual setup or other 
deployment tools (Docker, Ansible, etc.) can be used for application 
installation and configuration.
```

### 7. RDS Database (module: `rds`)

**Database Instance Configuration**
```
Identifier: bookreview-db
Engine: MySQL
Engine Version: 8.0 (latest)
Instance Class: db.t3.micro

Database Configuration:
├── Allocated Storage: 20 GB
├── Storage Type: gp2 (General Purpose)
├── Storage Encrypted: false (default)
├── Multi-AZ: false (can be enabled)
├── Publicly Accessible: false
└── Port: 3306 (MySQL default)

Availability & Backup:
├── Backup Retention: 0 days (Backups disabled)
├── Backup Window: N/A
├── Maintenance Window: Sunday 04:00-05:00 UTC
├── Deletion Protection: true
├── Final Snapshot: no
├── Multi-AZ: false
└── Read Replicas: false

Database Configuration:
├── DB Name: bookreview
├── Master Username: admin
├── Master Password: (provided at apply time)
├── Subnet Group: bookreview-db-subnet-group
└── Security Groups: rds-sg

Logging:
├── Error Logs: Enabled
├── General Logs: Enabled
└── Slow Query Logs: Enabled

Monitoring:
├── CloudWatch Logs: Enabled
└── Enhanced Monitoring: false
```

**DB Subnet Group**
```
Name: bookreview-db-subnet-group
Subnets:
├── 10.0.4.0/24 (Private DB - AZ-1)
└── 10.0.5.0/24 (Private DB - AZ-2)
```

## Data Flow Examples

### 1. User Request to Web Application

```
1. User sends HTTP request to public-alb.region.elb.amazonaws.com:80
2. Public ALB receives request in Public Subnet (AZ-1 or AZ-2)
3. ALB applies health check rules
4. ALB routes to healthy target (Web VM in registered target group)
5. Web VM receives request on port 80
6. Web application processes request
7. Response sent back through ALB to client
```

### 2. App Server to Database Connection

```
1. App VM runs Node.js application
2. App connects to internal-alb.local:3001
3. Internal ALB (in private app subnet) receives connection
4. ALB routes to healthy App VM on registered port 3001
5. App VM connects to RDS endpoint (bookreview-db.region.rds.amazonaws.com:3306)
6. RDS Security Group validates source (app-tier-sg)
7. MySQL connection established
8. Query execution and response
```

### 3. Outbound Internet Access from Private Subnets

```
1. App VM initiates outbound connection (e.g., package installation)
2. Route table directs traffic to NAT Gateway
3. NAT Gateway translates source IP to Elastic IP
4. Request sent to internet
5. Response returns to NAT Gateway
6. NAT Gateway translates back to App VM private IP
7. App VM receives response
```

## High Availability & Disaster Recovery

**Availability Characteristics**
- Multi-AZ deployment: Resources in 2 AZs
- Load Balancers: Distribute traffic across AZs
- EC2 Instances: 2 per tier, can scale to more
- RDS: Single-AZ (can enable Multi-AZ for HA)
- NAT Gateways: 2 for private subnet resilience

**Failure Scenarios**

```
Scenario 1: AZ-1 Failure
├── Public ALB: Still available in AZ-2
├── Web Tier: Web VM-2 (AZ-2) continues serving
├── App Tier: App VM-2 (AZ-2) continues services
└── RDS: Unaffected (single AZ currently)

Scenario 2: Web VM-1 Failure
├── Public ALB: Routes traffic to Web VM-2
├── Health checks: Detect failure in 30 seconds
├── Recovery: Auto-heal (if using ASG)
└── Impact: Minimal (load shifts to remaining instance)

Scenario 3: RDS Failure
├── Failover: Manual (if Multi-AZ enabled)
├── Recovery: From automated backups
└── Impact: Application downtime until recovery

Scenario 4: NAT Gateway Failure
├── Traffic: Routes to alternate NAT Gateway
├── Recovery: Automatic (AWS managed)
└── Impact: Minimal with 2 NAT Gateways
```

## Security Considerations

**Network Segmentation**
- Public Subnets: Only web tier, direct internet access
- Private Subnets: App and DB tiers, NAT-only access
- Security Groups: Enforce least privilege at each tier

**Encryption**
- In Transit: HTTP (can upgrade to HTTPS with ACM)
- At Rest: RDS storage not encrypted by default
- State File: Unencrypted locally (use S3 backend + encryption)

**Access Control**
- SSH Access: Limited to specified CIDR (admin IP)
- Database Access: Only from app tier security group
- ALB: Public access on port 80 only

**Compliance & Monitoring**
- CloudTrail: Track API calls
- VPC Flow Logs: Monitor network traffic
- RDS Enhanced Monitoring: Database metrics
- CloudWatch: Application metrics

## Cost Optimization

**Resource Allocation**
- t3.micro instances: Cost-effective, suitable for low traffic
- RDS db.t3.micro: Free tier eligible
- 20GB storage: Sufficient for development
- Single-AZ RDS: Reduces costs (add for production)

**Potential Optimizations**
- Reserved Instances: For production workloads
- Spot Instances: For fault-tolerant app tier
- RDS Reserved Instances: Commit term discount
- S3: For static content CDN
- CloudFront: Global content distribution

## Monitoring & Alerting Strategy

**Key Metrics to Monitor**
- ALB: Request count, target health, response time
- EC2: CPU utilization, network in/out
- RDS: Database connections, queries/sec, storage
- CloudWatch: Custom application metrics

**Recommended CloudWatch Alarms**
- ALB target unhealthy: Alert immediately
- RDS storage usage > 80%: Plan expansion
- High CPU utilization: Scale up instances
- NAT Gateway data transfer: Track costs

## Disaster Recovery Plan

**Backup Strategy**
```
RDS Automated Backups:
├── Retention: 7 days
├── Frequency: Daily
└── Recovery: Point-in-time restore

Manual Backups:
├── Frequency: Before major changes
├── Storage: S3
└── Test: Monthly restore drill

State File Backup:
├── Tool: Git version control
├── Location: GitHub private repo
└── Frequency: Each commit
```

**Recovery Procedures**
1. **RDS Recovery**: Use automated snapshot
2. **Instance Recovery**: Relaunch from AMI
3. **VPC Recovery**: Provision new VPC and redeploy
4. **Data Recovery**: Restore from backup snapshots

## Deployment Pipeline Integration

**Recommended CI/CD Setup**
```
GitHub Repository
│
└─→ GitHub Actions
    ├─→ terraform validate
    ├─→ terraform plan (PR preview)
    ├─→ terraform apply (merge to main)
    └─→ Smoke tests
```

**Infrastructure as Code Best Practices**
- Version control: All `.tf` files
- Code review: Pull requests before merge
- Testing: `terraform validate`, `terraform plan`
- Policy: OPA/Sentinel for governance
- Documentation: Keep README.md updated

---

**Last Updated**: 2024
**Terraform Version**: >= 1.0
**AWS Provider**: >= 5.0

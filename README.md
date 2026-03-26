# Terraform Book Review Application - Three Tier Architecture

A modular Terraform configuration for deploying a three-tier web application on AWS with the following structure:
- **Public Tier**: Web servers behind a public ALB in public subnets
- **Private Tier**: Application servers behind an internal ALB in private subnets
- **Database Tier**: AWS RDS MySQL database in private subnets

## Architecture Overview

```
Internet
    ↓
Public ALB (Port 80)
    ↓
Web VMs (Public Subnets) - Port 80
    ↓
Internal ALB (Port 3001)
    ↓
App VMs (Private Subnets) - Port 3001
    ↓
RDS MySQL Database (Private Subnets) - Port 3306
```

## Directory Structure

```
.
├── README.md                    # This file
├── DEPLOYMENT.md                # Deployment guide
├── providers.tf                 # AWS provider configuration
├── main.tf                      # Root module configuration
├── variables.tf                 # Root variables
├── terraform.tfvars             # Variable values
├── outputs.tf                   # Output values
├── .gitignore                   # Git ignore file
├── modules/
│   ├── networking/              # Networking module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security/                # Security groups module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── public_alb/              # Public load balancer module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── web_vm/                  # Web tier VMs module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── internal_alb/            # Internal load balancer module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── app_vm/                  # App tier VMs module
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rds/                     # RDS database module
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
```

## Prerequisites

- **Terraform**: >= 1.0
- **AWS CLI**: Configured with appropriate credentials
- **AWS Account**: With necessary permissions to create resources
- **AWS Region**: Default is `eu-west-2` (configurable)

### AWS Permissions Required

The AWS user or role must have permissions for:
- VPC and networking (VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables)
- Security Groups
- Application Load Balancers
- EC2 Instances
- RDS Instances
- IAM (if using IAM database authentication)

## Network Configuration

### VPC and Subnets

- **VPC CIDR**: 10.0.0.0/16
- **Public Web Subnets**: 2 across 2 AZs (10.0.0.0/24, 10.0.1.0/24)
- **Private App Subnets**: 2 across 2 AZs (10.0.2.0/24, 10.0.3.0/24)
- **Private DB Subnets**: 2 across 2 AZs (10.0.4.0/24, 10.0.5.0/24)

### Security Groups

1. **Public ALB SG**: 
   - Ingress: HTTP (80), HTTPS (443) from 0.0.0.0/0
   - Egress: All

2. **Web Tier SG**:
   - Ingress: HTTP (80) from Public ALB SG, SSH (22) from allowed CIDR
   - Egress: All

3. **Internal ALB SG**:
   - Ingress: Port 3001 from Web Tier SG
   - Egress: All

4. **App Tier SG**:
   - Ingress: Port 3001 from Internal ALB SG, SSH (22) from Web Tier SG
   - Egress: All

5. **RDS SG**:
   - Ingress: Port 3306 (MySQL) from App Tier SG
   - Egress: All

## Configuration Variables

### Key Variables (see `terraform.tfvars`)

```hcl
aws_region             = "eu-west-2"
environment            = "dev"
project_name           = "bookreview"

# Network Configuration
vpc_cidr              = "10.0.0.0/16"
enable_nat_gateway    = true

# Web Tier (1 deployed, design shows 2)
web_instance_type     = "t3.micro"
web_instance_count    = 1

# App Tier (1 deployed, design shows 2)
app_instance_type     = "t3.micro"
app_instance_count    = 1

# EC2 Key Pair
ec2_key_pair_name     = "terraform-vm"

# RDS
db_allocated_storage  = 20
db_instance_class     = "db.t3.micro"
db_engine              = "mysql"
db_engine_version      = "8.0"
```

## Important Security Considerations

⚠️ **BEFORE DEPLOYMENT**:

1. **SSH Access CIDR**: Update `allowed_ssh_cidr` in `terraform.tfvars` to your IP:
   ```hcl
   allowed_ssh_cidr = ["203.0.113.0/32"]  # Replace with your IP
   ```

2. **Database Credentials**: DO NOT commit database credentials to git:
   ```bash
   # Use environment variables or -var flags:
   terraform apply \
     -var="db_username=admin" \
     -var="db_password=YourSecurePassword123!"
   ```

3. **EC2 Key Pair**: Create the "terraform-vm" key pair in eu-west-2:
   ```bash
   aws ec2 create-key-pair --key-name terraform-vm --region eu-west-2 \
     --query 'KeyMaterial' --output text > terraform-vm.pem
   chmod 400 terraform-vm.pem
   ```
   The key pair name is already configured in `terraform.tfvars`

4. **Application Deployment**: No user data scripts are implemented
   - Manually install web server (nginx/Apache) on web VMs
   - Manually install application on app VMs
   - Use other deployment tools (Docker, Ansible, etc.) as needed

5. **Remote State**: Consider using S3 backend for production:
   - Uncomment the `backend` block in `providers.tf`
   - Update region to `eu-west-2`
   - Create S3 bucket and DynamoDB table for state locking

## Deployment

See [DEPLOYMENT.md](DEPLOYMENT.md) for detailed deployment instructions.

## Module Details

### Networking Module
- Creates VPC with custom CIDR
- Provisions 6 subnets across 2 AZs
- Configures Internet Gateway
- Sets up NAT Gateways for private subnet internet access
- Manages route tables for each tier

### Security Module
- Creates 5 security groups for different tiers
- Manages ingress and egress rules
- References security groups between tiers

### ALB Modules (Public and Internal)
- Configures Application Load Balancers
- Creates target groups
- Sets up listeners
- Includes health checks

### VM Modules (Web and App)
- Launches EC2 instances in specified subnets
- Registers instances with target groups
- Uses latest Amazon Linux 2 AMI
- Supports custom user data scripts

### RDS Module
- Creates MySQL database instance
- Configures multi-AZ (optional)
- Sets backup and maintenance windows
- Supports encryption and performance insights

## Outputs

After `terraform apply`, outputs include:
- VPC and subnet IDs
- ALB DNS names and ARNs
- EC2 instance IDs and IP addresses
- RDS endpoint and connection details

Access outputs:
```bash
terraform output
# or specific output:
terraform output public_alb_dns_name
```

## Cost Estimation

**Approximate monthly costs** (us-east-1, all in `free tier` eligible sizes):
- VPC and data transfer: ~$0-5
- 2x t3.micro EC2 instances (web): ~$8
- 2x t3.micro EC2 instances (app): ~$8
- ALB (both public and internal): ~$20
- NAT Gateway (2x): ~$45
- RDS db.t3.micro: ~$25 (if within free tier: $0)

**Estimated Total**: $100-150/month (varies by usage)

## Maintenance

### Updating Configuration
1. Modify variables in `terraform.tfvars`
2. Run `terraform plan` to review changes
3. Run `terraform apply` to implement changes

### Scaling
- Adjust `web_instance_count` and `app_instance_count` for horizontal scaling
- Change instance types for vertical scaling
- Modify ALB configuration for different behaviors

### Monitoring
- Use CloudWatch for metric monitoring
- Check RDS performance insights
- Review ALB access logs

## Troubleshooting

See [DEPLOYMENT.md](DEPLOYMENT.md) for troubleshooting tips.

## Best Practices Implemented

✅ **Modular Structure**: Code organized by function/tier
✅ **Reusable Modules**: Each module is self-contained
✅ **Variable Separation**: Clear separation of variables and values
✅ **Git Ignore**: Sensitive files excluded from version control
✅ **Resource Naming**: Consistent naming convention with project prefix
✅ **Tagging**: All resources tagged with Environment and Project
✅ **Security**: Security groups follow principle of least privilege
✅ **High Availability**: Resources distributed across multiple AZs
✅ **Documented**: Inline comments for complex configurations

## Support and Contributing

For issues, improvements, or questions:
1. Check existing documentation
2. Review Terraform AWS provider docs: https://registry.terraform.io/providers/hashicorp/aws/latest
3. Review module outputs and dependencies

## License

This Terraform configuration is provided as-is for educational and development purposes.

## References

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest)
- [AWS Best Practices](https://aws.amazon.com/architecture/best-practices/)

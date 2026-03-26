# Deployment Guide

## Prerequisites Checklist

Before deploying, ensure you have:

- [ ] Terraform installed (>= 1.0): `terraform version`
- [ ] AWS CLI configured: `aws configure`
- [ ] AWS credentials with appropriate permissions
- [ ] EC2 Key Pair "terraform-vm" created in eu-west-2
- [ ] Updated `allowed_ssh_cidr` with your IP
- [ ] Database password ready (strong, 8+ characters)

## Step 1: Review Configuration

```bash
# Navigate to project directory
cd /path/to/terraform-bookreview

# Review variables
cat terraform.tfvars

# Key configurations to verify:
# - aws_region (default: eu-west-2)
# - environment (default: dev)
# - project_name (default: bookreview)
# - ec2_key_pair_name (default: terraform-vm)
# - allowed_ssh_cidr (MUST UPDATE to your IP!)
# - Instance types and counts (currently 1 web, 1 app deployed)
```

## Step 2: Update Security Credentials

### Update SSH Access CIDR

Edit `terraform.tfvars`:
```hcl
allowed_ssh_cidr = ["YOUR_IP/32"]  # e.g., "203.0.113.45/32"
```

Get your IP:
```bash
curl https://checkip.amazonaws.com
```

### Create EC2 Key Pair

```bash
# Create key pair named terraform-vm
aws ec2 create-key-pair --key-name terraform-vm \
  --region eu-west-2 \
  --query 'KeyMaterial' --output text > terraform-vm.pem

# Set appropriate permissions
chmod 400 terraform-vm.pem

# The terraform.tfvars already has ec2_key_pair_name = "terraform-vm"
```

## Step 3: Initialize Terraform

```bash
# Initialize working directory
terraform init

# Output:
# - Downloads required providers
# - Creates .terraform directory
# - Initializes backend

# Verify initialization
ls -la .terraform
```

## Step 4: Plan Deployment

```bash
# Generate and review plan
terraform plan -out=tfplan

# Key outputs to review:
# - Number of resources to be created (~70+ resources)
# - VPC, subnets, security groups
# - Load balancers, EC2 instances
# - RDS instance

# For detailed plan
terraform plan -out=tfplan -detailed-exitcode
```

## Step 5: Apply Configuration

### Option A: With tfvars file (simpler)

```bash
# Provide DB credentials via -var flags
terraform apply \
  -var="db_username=admin" \
  -var="db_password=YourSecurePassword123!" \
  tfplan

# Or interactively:
terraform apply \
  -var="db_username=admin" \
  -var="db_password=YourSecurePassword123!"
```

### Option B: With environment variables (more secure)

```bash
# Set environment variables
export TF_VAR_db_username="admin"
export TF_VAR_db_password="YourSecurePassword123!"

# Apply
terraform apply tfplan
```

### Option C: Via variable file (advanced)

Create `secrets.tfvars` (add to .gitignore):
```hcl
db_username = "admin"
db_password = "YourSecurePassword123!"
```

Apply:
```bash
terraform apply -var-file="secrets.tfvars" tfplan
```

**IMPORTANT**: Never commit `secrets.tfvars` or actual passwords to git!

### Deployment Output

The apply command will:
1. Create VPC and subnets (5-10 minutes)
2. Create security groups
3. Create load balancers (5-10 minutes)
4. Launch EC2 instances (3-5 minutes)
5. Create RDS database (10-15 minutes)

**Total estimated time: 30-40 minutes**

## Step 6: Verify Deployment

### Get Outputs

```bash
# View all outputs
terraform output

# View specific output
terraform output public_alb_dns_name
terraform output rds_address
```

### Test Web Tier

```bash
# Get public ALB DNS
PUBLIC_ALB=$(terraform output -raw public_alb_dns_name)

# Test connectivity (Note: No web server auto-deployed, so this may fail)
# You need to install and start a web server on the instances first
curl http://$PUBLIC_ALB
curl -I http://$PUBLIC_ALB

# Once web server is installed, should return content
```

### Test RDS Connectivity (optional)

```bash
# Get RDS details
RDS_ENDPOINT=$(terraform output -raw rds_address)
RDS_PORT=$(terraform output -raw rds_port)
RDS_DB=$(terraform output -raw rds_database_name)
RDS_USER=$(terraform output -raw rds_master_username)

# From app VM or bastion:
mysql -h $RDS_ENDPOINT -P $RDS_PORT -u $RDS_USER -p

# Or from app VM:
ssh -i terraform-vm.pem ubuntu@<app-instance-ip>
mysql -h <rds-endpoint> -u admin -p -e "SELECT VERSION();"
```

### Verify Security Groups

```bash
# List security groups
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=bookreview" \
  --region eu-west-2 \
  --query 'SecurityGroups[].{Name: GroupName, ID: GroupId}'
```

### Verify Instances

```bash
# List EC2 instances
aws ec2 describe-instances --filters "Name=tag:Project,Values=bookreview" \
  --region eu-west-2 \
  --query 'Reservations[].Instances[].{ID: InstanceId, Type: InstanceType, IP: PrivateIpAddress, Subnet: SubnetId}'

# Check RDS instance
aws rds describe-db-instances --db-instance-identifier bookreview-db \
  --region eu-west-2 \
  --query 'DBInstances[0].{Engine: Engine, Status: DBInstanceStatus, Endpoint: Endpoint}'
```

## Step 7: Connect to Resources

### Connect to Web VM (via SSH)

```bash
# Get web instance public IP
WEB_IP=$(terraform output -raw -json web_instance_public_ips | jq -r '.[0]')

# SSH access with terraform-vm key
ssh -i terraform-vm.pem ubuntu@$WEB_IP

# Note: Web server is not automatically configured.
# You can install web server software using:
# sudo apt-get update && sudo apt-get install -y nginx
```

### Connect to App VM (via bastion/web server)

```bash
# From web server (which has internet access):
# 1. Copy terraform-vm.pem to web server
# 2. SSH from web server to app server (use private IP)

APP_IP=$(terraform output -raw -json app_instance_private_ips | jq -r '.[0]')

# From web server:
ssh -i terraform-vm.pem ubuntu@$APP_IP

# Note: App server is not automatically configured.
# You can install Node.js using:
# sudo apt-get update && sudo apt-get install -y nodejs npm
```

### Connect to RDS Database

```bash
# From app VM:
RDS_ENDPOINT=$(terraform output -raw rds_address)
mysql -h $RDS_ENDPOINT -u admin -p

# Test connection
mysql -h $RDS_ENDPOINT -u admin -p -e "SELECT DATABASE(), VERSION();"
```

## Step 8: Cleanup (Destroy)

### Important: Before destroying

```bash
# 1. Backup any important data
# 2. Disable deletion protection if needed

# Check what will be destroyed
terraform plan -destroy

# Destroy resources
terraform destroy \
  -var="db_username=admin" \
  -var="db_password=YourSecurePassword123!"

# Confirm deletion
# Type 'yes' when prompted
```

### Post-Cleanup

```bash
# Remove state files
rm -rf .terraform/
rm terraform.tfstate*

# Remove local keys
rm terraform-vm.pem

# Remove AWS key pair
aws ec2 delete-key-pair --key-name terraform-vm --region eu-west-2
```

## Troubleshooting

### Issue: "Insufficient capacity in AZ"

**Solution**: Change `aws_region` or try a different AZ combination

```bash
# Update terraform.tfvars (e.g., change to us-east-1)
sed -i 's/aws_region = "eu-west-2"/aws_region = "us-east-1"/' terraform.tfvars

# Re-plan and apply
terraform plan
terraform apply
```

### Issue: "InvalidGroup.NotFound" for security groups

**Cause**: Security groups referencing each other before creation

**Solution**: Apply again (usually resolves on second attempt)
```bash
terraform apply
```

### Issue: RDS takes too long / fails

**Cause**: Common with t3.micro in free tier

**Solution**: Use t3.small or wait for deployment to complete

```bash
# Check RDS status
aws rds describe-db-instances --db-instance-identifier bookreview-db \
  --region eu-west-2 \
  --query 'DBInstances[0].DBInstanceStatus'

# Expected states: creating → backing-up → available
```

### Issue: Cannot connect to web ALB

**Cause**: Target group health checks failing

**Solution**: Check instance health
```bash
# Get target group ARN
TG_ARN=$(terraform output -raw -json | jq -r '.public_alb_target_group_arn.value')

# Check targets
aws elbv2 describe-target-health --target-group-arn $TG_ARN \
  --region us-east-1
```

### Issue: EC2 instances in "impaired" state

**Cause**: Usually insufficient resources or misconfiguration

**Solution**: Check instance details
```bash
# Get instance status
aws ec2 describe-instance-status \
  --instance-ids <instance-id> \
  --region us-east-1
```

## Performance Tuning

### For production use:

```hcl
# Update terraform.tfvars for production
environment                    = "prod"
web_instance_type              = "t3.small"
app_instance_type              = "t3.small"
db_instance_class              = "db.t3.small"
db_multi_az                    = true
```

### Monitor costs

```bash
# Estimate monthly cost
# Use AWS Cost Calculator or check CloudWatch metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ApplicationELB \
  --metric-name ProcessedBytes \
  --dimensions Name=LoadBalancer,Value=<alb-name> \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 2592000 \
  --statistics Sum
```

## Updating Configuration

### Modify instance count

```bash
# Edit terraform.tfvars
# Change: web_instance_count = 3

# Plan and apply
terraform plan
terraform apply
```

### Upgrade instance types

```bash
# Edit terraform.tfvars
# Change: web_instance_type = "t3.small"

# Plan (will cause instance replacement)
terraform plan
terraform apply
```

### Update database

```bash
# Increase storage
terraform apply -var="db_allocated_storage=50"

# Note: Some changes require downtime
```

## Backup and Recovery

### Backup state

```bash
# Backup Terraform state
cp terraform.tfstate terraform.tfstate.backup
cp terraform.tfstate.backup ~/.terraform-backups/bookreview-$(date +%Y%m%d).backup
```

### Backup RDS data

```bash
# Note: RDS automatic backups use AWS default (1 day retention)
# For production, enable backup_retention_period in modules/rds/variables.tf
# Create manual backup
aws rds create-db-snapshot \
  --db-instance-identifier bookreview-db \
  --db-snapshot-identifier bookreview-db-backup-$(date +%Y%m%d)
```

## Security Best Practices

1. **Rotate credentials regularly**
   ```bash
   # Update RDS password
   aws rds modify-db-instance \
     --db-instance-identifier bookreview-db \
     --master-user-password NewPassword123! \
     --apply-immediately
   ```

2. **Enable encryption**
   - AWS KMS encryption (enable in variables)
   - TLS for RDS connections

3. **Monitor access**
   - CloudTrail logging
   - VPC Flow Logs
   - RDS Enhanced Monitoring

4. **Regular updates**
   - Apply security patches
   - Update Terraform configurations
   - Review dependency updates

## Next Steps

1. Deploy application to web and app tiers
2. Configure custom domain name (Route 53)
3. Set up SSL/TLS certificates (ACM)
4. Implement monitoring and alerting
5. Configure auto-scaling policies
6. Implement backup and disaster recovery

## Support Resources

- Terraform Docs: https://www.terraform.io/docs
- AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest
- AWS CLI: https://docs.aws.amazon.com/cli/
- RDS: https://docs.aws.amazon.com/rds/

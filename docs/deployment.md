# Search Sonar Deployment Guide

This guide provides step-by-step instructions for deploying the Search Sonar infrastructure to AWS.

## Prerequisites

### Required Tools
- **Terraform** >= 1.0 ([Install Guide](https://learn.hashicorp.com/tutorials/terraform/install-cli))
- **AWS CLI** >= 2.0 ([Install Guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html))
- **Git** for version control
- **jq** for JSON processing (optional but recommended)

### AWS Requirements
- AWS Account with appropriate permissions
- IAM user or role with the following policies:
  - `AmazonEC2FullAccess`
  - `AmazonRDSFullAccess`
  - `AmazonECSFullAccess`
  - `ElasticLoadBalancingFullAccess`
  - `AmazonElastiCacheFullAccess`
  - `AWSAmplifyFullAccess`
  - `CloudWatchFullAccess`
  - `IAMFullAccess`
  - `AmazonVPCFullAccess`
  - `SecretsManagerReadWrite`

### Application Requirements
- Docker images for your API and worker services
- GitHub repository for your application code
- Custom domain (optional)

## Initial Setup

### 1. Clone the Repository

```bash
git clone <your-infrastructure-repo-url>
cd search-sonar-infra
```

### 2. Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Verify credentials
aws sts get-caller-identity
```

### 3. Validate Infrastructure

```bash
# Run validation script
./scripts/validate.sh

# This will check:
# - Prerequisites installation
# - Module validation
# - Configuration file structure
```

## Configuration

### 1. Update Terraform Variables

#### Staging Environment
Edit `environments/staging/terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "ap-southeast-1"

# Project Configuration
project_name = "search-sonar"
environment  = "staging"

# Repository Configuration
repository_url = "https://github.com/yourusername/search-sonar"

# Domain Configuration (optional)
domain_name = "staging.yourdomain.com"

# Monitoring Configuration
alert_email = "admin@yourdomain.com"

# Container Images
api_image    = "your-registry/search-sonar-api:latest"
worker_image = "your-registry/search-sonar-worker:latest"
```

#### Production Environment
Edit `environments/production/terraform.tfvars`:

```hcl
# AWS Configuration
aws_region = "ap-southeast-1"

# Project Configuration
project_name = "search-sonar"
environment  = "production"

# Repository Configuration
repository_url = "https://github.com/yourusername/search-sonar"

# Domain Configuration
domain_name = "yourdomain.com"

# Monitoring Configuration
alert_email = "admin@yourdomain.com"

# Database Configuration (production sizing)
db_instance_class        = "db.t3.small"
db_allocated_storage     = 100
db_max_allocated_storage = 500

# Cache Configuration (production sizing)
redis_node_type       = "cache.t3.small"
redis_num_cache_nodes = 2

# ECS Configuration (production sizing)
api_cpu           = 1024
api_memory        = 2048
worker_cpu        = 512
worker_memory     = 1024
api_desired_count = 2

# Container Images
api_image    = "your-registry/search-sonar-api:latest"
worker_image = "your-registry/search-sonar-worker:latest"
```

### 2. Backend Configuration (Optional)

For production deployments, configure Terraform remote state:

#### Create S3 Bucket for State
```bash
aws s3 mb s3://your-terraform-state-bucket
aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled
```

#### Update Backend Configuration
Edit `environments/production/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "your-terraform-state-bucket"
    key    = "search-sonar/production/terraform.tfstate"
    region = "ap-southeast-1"

    # Optional: DynamoDB table for state locking
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Deployment Process

### Stage 1: Deploy Staging Environment

#### 1. Initialize Terraform
```bash
./scripts/deploy.sh staging init
```

#### 2. Plan Deployment
```bash
./scripts/deploy.sh staging plan
```

Review the plan output carefully. Ensure all resources are correct.

#### 3. Apply Changes
```bash
./scripts/deploy.sh staging apply
```

This will create:
- VPC and networking components
- RDS PostgreSQL database
- ElastiCache Redis cluster
- ECS cluster and services
- Application Load Balancer
- AWS Amplify application
- CloudWatch monitoring

#### 4. Verify Deployment
```bash
# Get deployment outputs
./scripts/deploy.sh staging output

# Check service health
aws ecs describe-services \
  --cluster search-sonar-staging-cluster \
  --services search-sonar-staging-api

# Test API endpoint
curl -f $(terraform output -raw api_url)/health
```

### Stage 2: Test Staging Environment

#### 1. Frontend Testing
- Visit the Amplify URL from the outputs
- Verify the application loads correctly
- Test API connectivity

#### 2. Backend Testing
- Check ECS service logs in CloudWatch
- Verify database connectivity
- Test worker job processing

#### 3. Monitoring Verification
- Access CloudWatch dashboard
- Verify alerts are configured
- Test SNS notifications

### Stage 3: Deploy Production Environment

#### 1. Plan Production Deployment
```bash
./scripts/deploy.sh production plan
```

#### 2. Apply Production Changes
```bash
./scripts/deploy.sh production apply
```

**Note:** This will prompt for confirmation due to production environment.

#### 3. Configure Domain (if applicable)
If using a custom domain, update your DNS settings:

```bash
# Get the load balancer DNS name
terraform output load_balancer_dns_name

# Update your domain's DNS records to point to the ALB
```

#### 4. Verify Production Deployment
```bash
# Get production outputs
./scripts/deploy.sh production output

# Test production endpoints
curl -f $(terraform output -raw api_url)/health
```

## Post-Deployment Configuration

### 1. Amplify Setup

#### Connect GitHub Repository
1. Go to AWS Amplify Console
2. Find your application (search-sonar-production-web)
3. Connect your GitHub repository
4. Configure build settings
5. Set environment variables

#### Environment Variables for Amplify
```
VITE_API_URL=https://your-api-domain.com
VITE_APP_NAME=Search Sonar
NODE_ENV=production
```

### 2. Database Setup

#### Run Database Migrations
```bash
# Get database connection details
aws secretsmanager get-secret-value \
  --secret-id search-sonar-production-db-connection \
  --query SecretString --output text | jq -r .url

# Run your application's database migrations
# This depends on your application setup
```

### 3. Container Images

#### Update ECS Services with Your Images
```bash
# Update API service
aws ecs update-service \
  --cluster search-sonar-production-cluster \
  --service search-sonar-production-api \
  --force-new-deployment

# Update worker service
aws ecs update-service \
  --cluster search-sonar-production-cluster \
  --service search-sonar-production-worker \
  --force-new-deployment
```

## Monitoring Setup

### 1. CloudWatch Dashboards
- Access the dashboard URL from terraform outputs
- Customize widgets as needed
- Set up additional custom metrics

### 2. Alerting Configuration
- Verify SNS topic subscription
- Test alert notifications
- Configure additional alerts as needed

### 3. Log Analysis
- Set up CloudWatch Log Insights queries
- Configure log retention policies
- Set up log-based metrics

## Maintenance Operations

### 1. Updating Infrastructure
```bash
# Plan changes
./scripts/deploy.sh production plan

# Apply updates
./scripts/deploy.sh production apply
```

### 2. Scaling Services
Update the desired count in terraform.tfvars:
```hcl
api_desired_count = 4
worker_desired_count = 2
```

Then apply changes:
```bash
./scripts/deploy.sh production apply
```

### 3. Database Maintenance
- Automated backups are configured
- Monitor performance metrics
- Scale instance class as needed

### 4. Security Updates
- Regularly update container images
- Monitor AWS security bulletins
- Update Terraform modules

## Troubleshooting

### Common Issues

#### 1. Terraform Init Fails
```bash
# Check AWS credentials
aws sts get-caller-identity

# Verify Terraform version
terraform version

# Clear Terraform cache
rm -rf .terraform
terraform init
```

#### 2. ECS Service Won't Start
```bash
# Check service events
aws ecs describe-services \
  --cluster your-cluster-name \
  --services your-service-name

# Check task logs
aws logs get-log-events \
  --log-group-name /ecs/search-sonar/api \
  --log-stream-name your-log-stream
```

#### 3. Database Connection Issues
```bash
# Verify security groups
aws ec2 describe-security-groups \
  --group-ids your-security-group-id

# Test database connectivity from ECS task
aws ecs execute-command \
  --cluster your-cluster \
  --task your-task-id \
  --container api \
  --interactive \
  --command "/bin/bash"
```

#### 4. Load Balancer Health Checks Failing
```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn your-target-group-arn

# Verify health check endpoint
curl -f http://your-alb-dns-name/health
```

### Getting Help

1. Check CloudWatch logs for detailed error messages
2. Review AWS service health dashboard
3. Verify security group and network ACL rules
4. Check IAM permissions for ECS tasks
5. Review Terraform state for resource configuration

## Cleanup

### Destroying Resources

#### Staging Environment
```bash
./scripts/destroy.sh staging
```

#### Production Environment
```bash
./scripts/destroy.sh production
```

**Warning:** This will permanently delete all resources and data.

### Partial Cleanup
To remove specific resources, use Terraform targeting:
```bash
terraform destroy -target=module.frontend
```

## Next Steps

1. Set up CI/CD pipelines for your application
2. Configure monitoring and alerting
3. Implement backup and disaster recovery procedures
4. Set up development and testing workflows
5. Document operational procedures

This completes the deployment of your Search Sonar infrastructure. Your application should now be running on AWS with full monitoring, security, and scalability features.
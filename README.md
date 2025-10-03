# Search Sonar Infrastructure

This repository contains the complete AWS infrastructure setup for the Search Sonar application - a monorepo with React + Vite frontend, NestJS API, and worker scraper services.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                         AWS Cloud                            │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────┐         ┌──────────────┐                  │
│  │   Frontend   │         │   Backend    │                  │
│  │  (Amplify)   │────────▶│   (ECS +     │                  │
│  │ React+Vite   │         │   Fargate)   │                  │
│  └──────────────┘         └──────┬───────┘                  │
│                                   │                           │
│                          ┌────────▼────────┐                 │
│                          │   Worker Jobs   │                 │
│                          │  (ECS Fargate)  │                 │
│                          └────────┬────────┘                 │
│                                   │                           │
│                          ┌────────▼────────┐                 │
│                          │   BullMQ Queue  │                 │
│                          │  (ElastiCache   │                 │
│                          │     Redis)      │                 │
│                          └────────┬────────┘                 │
│                                   │                           │
│                          ┌────────▼────────┐                 │
│                          │   PostgreSQL    │                 │
│                          │      (RDS)      │                 │
│                          └─────────────────┘                 │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Components

### Frontend (React + Vite)
- **AWS Amplify** for hosting and CI/CD
- Automatic deployments from Git
- Custom domain support
- Branch-based deployments

### API (NestJS)
- **ECS Fargate** for container orchestration
- **Application Load Balancer** for traffic distribution
- Auto-scaling based on demand
- Health checks and monitoring

### Worker (Scraper Jobs)
- **ECS Fargate** for background job processing
- **BullMQ** for job queue management
- Scalable worker instances
- Job monitoring and error handling

### Database
- **RDS PostgreSQL** with automated backups
- Read replicas for production
- Encryption at rest and in transit
- Performance monitoring

### Cache & Queue
- **ElastiCache Redis** for BullMQ
- High availability with Multi-AZ
- Automatic failover
- Memory optimization for job queues

### Monitoring & Logging
- **CloudWatch** dashboards and alarms
- **SNS** notifications for alerts
- Log aggregation and analysis
- Performance metrics tracking

## 📁 Project Structure

```
search-sonar-infra/
├── modules/                    # Reusable Terraform modules
│   ├── networking/            # VPC, subnets, security groups
│   ├── database/              # RDS PostgreSQL setup
│   ├── cache/                 # ElastiCache Redis setup
│   ├── ecs-cluster/           # ECS cluster and services
│   ├── load-balancer/         # Application Load Balancer
│   ├── frontend/              # AWS Amplify setup
│   └── monitoring/            # CloudWatch and alerting
├── environments/              # Environment-specific configurations
│   ├── production/            # Production environment
│   └── staging/               # Staging environment
├── scripts/                   # Deployment and utility scripts
│   ├── deploy.sh             # Main deployment script
│   ├── validate.sh           # Configuration validation
│   └── destroy.sh            # Resource cleanup script
└── docs/                     # Documentation
```

## 🛠️ Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** >= 1.0
3. **AWS CLI** configured with credentials
4. **Git repository** for your application code
5. **Docker images** for your API and worker services

## ⚡ Quick Start

### Deployment Options

Choose your preferred deployment method:

#### Option A: GitHub Actions (Recommended) 🤖

Automated CI/CD with GitHub Actions for production-ready deployments.

**Setup:**
```bash
# 1. Set up GitHub secrets automatically
./scripts/setup-github-secrets.sh

# 2. Set up GitHub environments (manual step)
# Go to Settings > Environments and create: staging, production

# 3. Deploy via GitHub Actions
# - Push to main branch = automatic staging deployment
# - Use Actions tab for manual production deployment
```

**Benefits:**
- ✅ Automated validation and deployment
- ✅ Pull request planning and review
- ✅ Environment protection rules
- ✅ Deployment summaries and links
- ✅ Audit trail and rollback capability

[📚 **Detailed GitHub Actions Guide**](docs/github-actions.md)

#### Option B: Local Deployment 💻

Direct deployment from your local machine.

### 1. Clone and Configure

```bash
git clone <your-repo-url>
cd search-sonar-infra

# Validate the infrastructure
./scripts/validate.sh
```

### 2. Update Configuration

Edit the terraform.tfvars files for your environments:

```bash
# Production configuration
vim environments/production/terraform.tfvars

# Staging configuration
vim environments/staging/terraform.tfvars
```

**Required updates:**
- `repository_url`: Your GitHub repository URL
- `api_image`: Your API Docker image
- `worker_image`: Your worker Docker image
- `domain_name`: Your custom domain (optional)
- `alert_email`: Email for monitoring alerts

### 3. Deploy Staging Environment

```bash
# Initialize Terraform
./scripts/deploy.sh staging init

# Plan the deployment
./scripts/deploy.sh staging plan

# Apply the changes
./scripts/deploy.sh staging apply
```

### 4. Deploy Production Environment

```bash
# Plan production deployment
./scripts/deploy.sh production plan

# Apply to production (with confirmation)
./scripts/deploy.sh production apply
```

## 📋 Deployment Commands

### Basic Operations
```bash
# Validate configuration
./scripts/validate.sh [environment]

# Initialize Terraform
./scripts/deploy.sh [environment] init

# Plan changes
./scripts/deploy.sh [environment] plan

# Apply changes
./scripts/deploy.sh [environment] apply

# Show outputs
./scripts/deploy.sh [environment] output

# Destroy resources
./scripts/destroy.sh [environment]
```

### Examples
```bash
# Deploy to staging
./scripts/deploy.sh staging apply

# Plan production changes
./scripts/deploy.sh production plan

# Get production outputs
./scripts/deploy.sh production output

# Destroy staging environment
./scripts/destroy.sh staging
```

## 🔧 Configuration

### Environment Variables

Each environment has its own `terraform.tfvars` file with these key variables:

| Variable | Description | Example |
|----------|-------------|---------|
| `repository_url` | GitHub repository URL | `https://github.com/user/repo` |
| `domain_name` | Custom domain (optional) | `searchsonar.com` |
| `alert_email` | Email for alerts | `admin@company.com` |
| `api_image` | API Docker image | `your-registry/api:latest` |
| `worker_image` | Worker Docker image | `your-registry/worker:latest` |

### Resource Sizing

**Production (High Availability):**
- API: 2 instances, 512 CPU, 1024 MB memory
- Worker: 1 instance, 512 CPU, 1024 MB memory
- Database: db.t3.small with read replica
- Redis: 2 nodes for high availability

**Staging (Cost Optimized):**
- API: 1 instance, 256 CPU, 512 MB memory
- Worker: 1 instance, 256 CPU, 512 MB memory
- Database: db.t3.micro, no read replica
- Redis: 1 node, no NAT gateway

## 🔐 Security Features

- **VPC** with public/private subnet isolation
- **Security Groups** with least-privilege access
- **Secrets Manager** for database and Redis credentials
- **SSL/TLS** encryption for all communications
- **IAM roles** with minimal required permissions
- **Database encryption** at rest and in transit

## 📊 Monitoring & Alerting

### CloudWatch Dashboards
- Application Load Balancer metrics
- ECS service performance
- Database performance
- Redis cache metrics

### Automated Alerts
- High response times
- Service health issues
- Database connection problems
- Worker job failures
- Resource utilization thresholds

### Log Management
- Centralized logging in CloudWatch
- Log retention policies
- Error tracking and analysis
- Performance monitoring

## 🔄 CI/CD Integration

### Frontend (Amplify)
- Automatic deployments on Git push
- Branch-based preview deployments
- Build optimization for Vite
- Environment variable management

### Backend Services
- Manual deployment of Docker images
- Blue-green deployment support
- Health check integration
- Rollback capabilities

## 💰 Cost Optimization

### Staging Environment
- Single AZ deployment
- Smaller instance sizes
- No NAT Gateway
- Reduced backup retention
- No read replicas

### Production Environment
- Multi-AZ for high availability
- Auto-scaling for cost efficiency
- Reserved instances (recommended)
- Lifecycle policies for logs
- Monitoring for unused resources

## 🚨 Troubleshooting

### Common Issues

1. **Terraform Init Fails**
   ```bash
   # Check AWS credentials
   aws sts get-caller-identity

   # Verify Terraform version
   terraform version
   ```

2. **Deployment Fails**
   ```bash
   # Validate configuration
   ./scripts/validate.sh staging

   # Check detailed logs
   terraform plan -detailed-exitcode
   ```

3. **Service Health Issues**
   - Check CloudWatch logs
   - Verify security group rules
   - Confirm environment variables
   - Check container image availability

### Getting Help

1. Check the CloudWatch dashboard
2. Review ECS service logs
3. Verify security group configurations
4. Check Secrets Manager for credentials
5. Review Terraform state for resource status

## 📚 Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [AWS Amplify Documentation](https://docs.aws.amazon.com/amplify/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [BullMQ Documentation](https://docs.bullmq.io/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test with staging environment
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
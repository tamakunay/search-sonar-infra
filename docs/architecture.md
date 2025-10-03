# Search Sonar Infrastructure Architecture

## Overview

The Search Sonar infrastructure is designed as a modern, scalable, and secure cloud-native application running on AWS. It supports a monorepo application with three main components: a React frontend, a NestJS API, and a worker service for background job processing.

## Architecture Principles

### 1. **Microservices Architecture**
- Separate services for API and worker functionality
- Independent scaling and deployment
- Fault isolation between components

### 2. **Infrastructure as Code**
- All infrastructure defined in Terraform
- Version-controlled and reproducible deployments
- Environment parity between staging and production

### 3. **Security First**
- Network isolation with VPC and private subnets
- Secrets management with AWS Secrets Manager
- Least-privilege IAM roles and policies
- Encryption at rest and in transit

### 4. **High Availability**
- Multi-AZ deployment for production
- Auto-scaling for ECS services
- Database read replicas
- Redis clustering for cache availability

### 5. **Observability**
- Comprehensive monitoring with CloudWatch
- Centralized logging
- Automated alerting
- Performance metrics tracking

## Component Architecture

### Frontend Layer

**AWS Amplify**
- Hosts the React + Vite application
- Provides CI/CD pipeline from Git
- Global CDN for fast content delivery
- Automatic SSL certificate management
- Branch-based deployments for feature testing

**Key Features:**
- Automatic builds on Git push
- Environment variable management
- Custom domain support
- SPA routing configuration
- API proxy rules for backend communication

### Application Layer

**ECS Fargate Cluster**
- Container orchestration for API and worker services
- Serverless container execution
- Auto-scaling based on CPU/memory utilization
- Health checks and automatic recovery

**API Service:**
- NestJS application running in containers
- Handles HTTP requests from frontend
- Connects to PostgreSQL database
- Publishes jobs to Redis queue
- Horizontal scaling based on load

**Worker Service:**
- Background job processing
- Consumes jobs from BullMQ queue
- Performs web scraping and data processing
- Updates database with results
- Independent scaling from API

### Data Layer

**Amazon RDS PostgreSQL**
- Primary database for application data
- Automated backups and point-in-time recovery
- Read replicas for production workloads
- Performance monitoring and optimization
- Encryption at rest with KMS

**ElastiCache Redis**
- Job queue management with BullMQ
- Session storage and caching
- High availability with Multi-AZ
- Automatic failover
- Memory optimization for queue operations

### Network Architecture

**VPC Design**
```
┌─────────────────────────────────────────────────────────────┐
│                      VPC (10.0.0.0/16)                      │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌─────────────────┐         ┌─────────────────┐            │
│  │  Public Subnet  │         │  Public Subnet  │            │
│  │   10.0.1.0/24   │         │   10.0.2.0/24   │            │
│  │      AZ-1a      │         │      AZ-1b      │            │
│  │                 │         │                 │            │
│  │  ┌─────────────┐│         │ ┌─────────────┐ │            │
│  │  │     ALB     ││         │ │ NAT Gateway │ │            │
│  │  └─────────────┘│         │ └─────────────┘ │            │
│  └─────────────────┘         └─────────────────┘            │
│                                                               │
│  ┌─────────────────┐         ┌─────────────────┐            │
│  │ Private Subnet  │         │ Private Subnet  │            │
│  │  10.0.10.0/24   │         │  10.0.20.0/24   │            │
│  │      AZ-1a      │         │      AZ-1b      │            │
│  │                 │         │                 │            │
│  │ ┌─────────────┐ │         │ ┌─────────────┐ │            │
│  │ │ ECS Tasks   │ │         │ │ ECS Tasks   │ │            │
│  │ │   Redis     │ │         │ │   Redis     │ │            │
│  │ └─────────────┘ │         │ └─────────────┘ │            │
│  └─────────────────┘         └─────────────────┘            │
│                                                               │
│  ┌─────────────────┐         ┌─────────────────┐            │
│  │Database Subnet  │         │Database Subnet  │            │
│  │ 10.0.100.0/24   │         │ 10.0.200.0/24   │            │
│  │      AZ-1a      │         │      AZ-1b      │            │
│  │                 │         │                 │            │
│  │ ┌─────────────┐ │         │ ┌─────────────┐ │            │
│  │ │ PostgreSQL  │ │         │ │ Read Replica│ │            │
│  │ └─────────────┘ │         │ └─────────────┘ │            │
│  └─────────────────┘         └─────────────────┘            │
└─────────────────────────────────────────────────────────────┘
```

**Security Groups:**
- ALB Security Group: Allows HTTP/HTTPS from internet
- ECS Security Group: Allows traffic from ALB only
- RDS Security Group: Allows PostgreSQL from ECS only
- Redis Security Group: Allows Redis from ECS only

### Load Balancing

**Application Load Balancer**
- Distributes traffic across ECS tasks
- SSL termination with ACM certificates
- Health checks for backend services
- Path-based routing for API endpoints
- Integration with Route53 for custom domains

**Target Groups:**
- API target group for NestJS application
- Health check endpoint: `/health`
- Sticky sessions disabled for stateless design

### Security Architecture

**Network Security:**
- Private subnets for application and data layers
- NAT Gateway for outbound internet access
- Security groups with least-privilege rules
- Network ACLs for additional protection

**Identity and Access Management:**
- ECS Task Execution Role for container management
- ECS Task Role for application permissions
- Secrets Manager access for database credentials
- CloudWatch Logs permissions for monitoring

**Data Protection:**
- RDS encryption at rest with KMS
- ElastiCache encryption in transit
- Secrets Manager for credential storage
- SSL/TLS for all communications

### Monitoring and Observability

**CloudWatch Integration:**
- Custom dashboards for all components
- Automated alarms for critical metrics
- Log aggregation from all services
- Performance insights for database

**Key Metrics:**
- Application Load Balancer response times
- ECS service CPU and memory utilization
- Database connection count and performance
- Redis memory usage and connections
- Worker job processing rates

**Alerting:**
- SNS topics for critical alerts
- Email notifications for administrators
- Escalation policies for production issues
- Integration with external monitoring tools

## Deployment Architecture

### Environment Strategy

**Staging Environment:**
- Cost-optimized configuration
- Single AZ deployment
- Smaller instance sizes
- Reduced backup retention
- Development branch deployments

**Production Environment:**
- High availability configuration
- Multi-AZ deployment
- Auto-scaling enabled
- Enhanced monitoring
- Read replicas for database

### CI/CD Pipeline

**Frontend (Amplify):**
1. Git push triggers build
2. Amplify builds React application
3. Deploys to global CDN
4. Updates DNS records
5. Notifies on completion

**Backend Services:**
1. Docker images built externally
2. Images pushed to ECR
3. ECS service updated with new image
4. Rolling deployment with health checks
5. Rollback on failure

## Scalability Considerations

### Horizontal Scaling
- ECS services auto-scale based on metrics
- Database read replicas for read-heavy workloads
- Redis clustering for cache scalability
- CDN for global content distribution

### Vertical Scaling
- ECS task definitions support CPU/memory adjustments
- Database instance class can be upgraded
- Redis node types can be changed
- Load balancer capacity automatically adjusts

### Performance Optimization
- Connection pooling for database
- Redis caching for frequently accessed data
- CDN caching for static assets
- Optimized container images

## Disaster Recovery

### Backup Strategy
- Automated RDS backups with point-in-time recovery
- Redis snapshots for cache restoration
- Infrastructure code in version control
- Configuration stored in Terraform state

### Recovery Procedures
- Database restoration from automated backups
- Infrastructure recreation from Terraform
- Application deployment from container images
- DNS failover for multi-region setup

## Cost Optimization

### Resource Efficiency
- Fargate pricing model for actual usage
- Auto-scaling to match demand
- Reserved instances for predictable workloads
- Lifecycle policies for log retention

### Monitoring and Alerts
- Cost anomaly detection
- Resource utilization monitoring
- Unused resource identification
- Budget alerts and controls

This architecture provides a robust, scalable, and secure foundation for the Search Sonar application while maintaining cost efficiency and operational simplicity.
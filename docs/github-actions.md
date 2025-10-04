# GitHub Actions CI/CD Setup

This document explains how to set up and use GitHub Actions for automated deployment of your Search Sonar infrastructure.

## 🚀 Quick Start

### 1. Set up GitHub Secrets

Go to your repository **Settings > Secrets and variables > Actions** and add these secrets:

```
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=ap-southeast-1
```

### 2. Set up GitHub Environments

Go to **Settings > Environments** and create:

- **staging** - No protection rules needed
- **production** - Add protection rules:
  - Required reviewers (recommended)
  - Restrict pushes to protected branches
- **staging-destroy** - For staging destruction (optional protection)
- **production-destroy** - For production destruction (require reviewers)

## 📋 Workflow Overview

The GitHub Actions workflow provides:

### Automatic Triggers
- **Pull Requests**: Runs validation and staging plan
- **Push to main**: Deploys to staging automatically
- **Manual Dispatch**: Deploy to any environment with any action

### Jobs
1. **validate** - Validates Terraform syntax and configuration
2. **plan-staging** - Creates execution plan for staging
3. **deploy-staging** - Deploys to staging environment
4. **plan-production** - Creates execution plan for production
5. **deploy-production** - Deploys to production environment
6. **destroy** - Destroys infrastructure (manual only)

## 🎯 Usage Scenarios

### Scenario 1: Development Workflow (Automatic)
```bash
# 1. Create feature branch
git checkout -b feature/new-infrastructure

# 2. Make changes to Terraform files
# Edit files in environments/ or modules/

# 3. Create Pull Request
# GitHub Actions will:
# - Validate Terraform
# - Run staging plan
# - Comment plan results on PR

# 4. Merge to main
# GitHub Actions will:
# - Deploy to staging automatically
```

### Scenario 2: Manual Staging Deployment
1. Go to **Actions** tab in GitHub
2. Select **Search Sonar Infrastructure CI/CD**
3. Click **Run workflow**
4. Choose:
   - Environment: `staging`
   - Action: `apply`
5. Click **Run workflow**

### Scenario 3: Production Deployment
1. Go to **Actions** tab in GitHub
2. Select **Search Sonar Infrastructure CI/CD**
3. Click **Run workflow**
4. Choose:
   - Environment: `production`
   - Action: `plan` (first run plan)
5. Review the plan output
6. Run again with:
   - Environment: `production`
   - Action: `apply`

### Scenario 4: Destroy Infrastructure
1. Go to **Actions** tab in GitHub
2. Select **Search Sonar Infrastructure CI/CD**
3. Click **Run workflow**
4. Choose:
   - Environment: `staging` or `production`
   - Action: `destroy`
5. Click **Run workflow**

## 🔧 Workflow Features

### Security
- Uses GitHub Environments for deployment protection
- Requires manual approval for production deployments
- Stores AWS credentials as encrypted secrets
- Uses least-privilege IAM permissions

### Efficiency
- Validates all environments in parallel
- Caches Terraform plans between jobs
- Only runs on relevant file changes
- Provides detailed deployment summaries

### Visibility
- Comments Terraform plans on Pull Requests
- Creates deployment summaries with links
- Uploads plan artifacts for review
- Provides step-by-step execution logs

## 📊 Deployment Outputs

After successful deployment, you'll see:

### Staging Deployment Summary
```
🚀 Staging Deployment Complete!

📊 Infrastructure Outputs
- API URL: https://staging-alb-123456789.ap-southeast-1.elb.amazonaws.com
- Frontend URL: https://staging.d1234567890123.amplifyapp.com
- CloudWatch Dashboard: https://console.aws.amazon.com/cloudwatch/...

🔗 Quick Links
- View API
- View Frontend  
- View Monitoring
```

## 🛠️ Customization

### Modify Environments
Edit `.github/workflows/terraform.yml`:

```yaml
# Add new environment
workflow_dispatch:
  inputs:
    environment:
      options:
        - staging
        - production
        - development  # Add new environment
```

### Change Terraform Version
```yaml
env:
  TF_VERSION: '1.13.3'  # Update version here
```

### Add Slack Notifications
Add this step to deployment jobs:

```yaml
- name: Slack Notification
  uses: 8398a7/action-slack@v3
  with:
    status: ${{ job.status }}
    webhook_url: ${{ secrets.SLACK_WEBHOOK }}
```

## 🚨 Troubleshooting

### Common Issues

**1. AWS Credentials Error**
```
Error: could not retrieve caller identity
```
- Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY secrets
- Verify IAM user has required permissions

**2. Terraform State Lock**
```
Error: Error acquiring the state lock
```
- Wait for other operations to complete
- Check if previous job was cancelled mid-execution

**3. Plan Artifact Not Found**
```
Error: Artifact 'staging-tfplan' not found
```
- This happens when plan shows no changes
- The apply job will run `terraform apply` without a plan file

**4. Environment Protection Rules**
```
Error: Environment protection rules not satisfied
```
- Check if required reviewers have approved
- Verify you have permission to deploy to the environment

### Getting Help

1. Check the **Actions** tab for detailed logs
2. Review the deployment summary in each job
3. Check AWS CloudWatch for infrastructure issues
4. Verify your Terraform configuration locally first

## 📚 Next Steps

1. **Set up monitoring alerts** - Configure SNS notifications
2. **Add integration tests** - Test deployed infrastructure
3. **Implement blue-green deployments** - For zero-downtime updates
4. **Add cost monitoring** - Track infrastructure costs
5. **Set up backup strategies** - Automate data backups

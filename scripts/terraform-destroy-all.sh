#!/bin/bash

# Terraform destroy script for Search Sonar infrastructure
# This script destroys all Terraform-managed resources

set -e

ENVIRONMENT="${1:-staging}"
AWS_REGION="ap-southeast-1"

echo "💥 Terraform Destroy for Search Sonar"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo ""

echo "⚠️  WARNING: This will destroy ALL Terraform-managed resources!"
echo "This includes:"
echo "- All infrastructure resources"
echo "- Databases (data will be lost!)"
echo "- Load balancers"
echo "- ECS clusters and services"
echo "- VPC and networking"
echo "- Everything managed by Terraform"
echo ""

read -p "Are you sure you want to DESTROY everything? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Destroy cancelled."
    exit 1
fi

echo ""
echo "💥 Starting Terraform destroy..."

cd "environments/$ENVIRONMENT"

# First try to destroy normally
echo "🔄 Running terraform destroy..."
if terraform destroy -auto-approve; then
    echo "✅ Terraform destroy completed successfully!"
else
    echo "⚠️  Terraform destroy had issues. Checking state..."
    
    # Show what's left in state
    echo ""
    echo "📋 Resources still in state:"
    terraform state list || true
    
    echo ""
    echo "🔧 You may need to:"
    echo "1. Run the comprehensive cleanup script: ../../scripts/cleanup-failed-deployment.sh"
    echo "2. Manually delete remaining resources from AWS Console"
    echo "3. Run 'terraform state rm <resource>' for stuck resources"
    echo "4. Run 'terraform destroy' again"
fi

echo ""
echo "🏁 Destroy process completed!"

#!/bin/bash

# Update container images and trigger deployment
# Usage: ./scripts/update-images.sh [environment] [git-commit-hash]

set -e

ENVIRONMENT=${1:-staging}
GIT_COMMIT=${2:-$(git rev-parse HEAD | cut -c1-8)}
AWS_REGION="ap-southeast-1"
AWS_ACCOUNT_ID="210901781719"

echo "🚀 Updating Search Sonar container images"
echo "Environment: $ENVIRONMENT"
echo "Git Commit: $GIT_COMMIT"
echo "AWS Region: $AWS_REGION"
echo ""

# Construct image URIs
API_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/search-sonar-api-$ENVIRONMENT:$GIT_COMMIT"
WORKER_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/search-sonar-worker-$ENVIRONMENT:$GIT_COMMIT"

echo "📦 New image URIs:"
echo "API: $API_IMAGE"
echo "Worker: $WORKER_IMAGE"
echo ""

# Check if images exist in ECR
echo "🔍 Checking if images exist in ECR..."

if ! aws ecr describe-images --repository-name "search-sonar-api-$ENVIRONMENT" --image-ids imageTag="$GIT_COMMIT" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "❌ API image with tag '$GIT_COMMIT' not found in ECR"
    echo "Please build and push your images first:"
    echo "  docker build -t search-sonar-api ."
    echo "  docker tag search-sonar-api:latest $API_IMAGE"
    echo "  docker push $API_IMAGE"
    exit 1
fi

if ! aws ecr describe-images --repository-name "search-sonar-worker-$ENVIRONMENT" --image-ids imageTag="$GIT_COMMIT" --region "$AWS_REGION" >/dev/null 2>&1; then
    echo "❌ Worker image with tag '$GIT_COMMIT' not found in ECR"
    echo "Please build and push your images first:"
    echo "  docker build -t search-sonar-worker ."
    echo "  docker tag search-sonar-worker:latest $WORKER_IMAGE"
    echo "  docker push $WORKER_IMAGE"
    exit 1
fi

echo "✅ Both images found in ECR"
echo ""

# Update terraform.tfvars
TFVARS_FILE="environments/$ENVIRONMENT/terraform.tfvars"

if [ ! -f "$TFVARS_FILE" ]; then
    echo "❌ Terraform variables file not found: $TFVARS_FILE"
    exit 1
fi

echo "📝 Updating $TFVARS_FILE..."

# Create backup
cp "$TFVARS_FILE" "$TFVARS_FILE.backup"

# Update image URIs using sed
sed -i.tmp "s|api_image.*=.*|api_image = \"$API_IMAGE\"|g" "$TFVARS_FILE"
sed -i.tmp "s|worker_image.*=.*|worker_image = \"$WORKER_IMAGE\"|g" "$TFVARS_FILE"
rm "$TFVARS_FILE.tmp"

echo "✅ Updated terraform variables"
echo ""

# Show the changes
echo "📋 Changes made:"
echo "Before:"
grep -E "(api_image|worker_image)" "$TFVARS_FILE.backup" || true
echo ""
echo "After:"
grep -E "(api_image|worker_image)" "$TFVARS_FILE" || true
echo ""

# Ask for confirmation
read -p "🚀 Do you want to commit these changes and trigger deployment? (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Commit changes
    git add "$TFVARS_FILE"
    git commit -m "feat: update container images to $GIT_COMMIT

- API: $API_IMAGE
- Worker: $WORKER_IMAGE
- Environment: $ENVIRONMENT"
    
    echo "✅ Changes committed"
    
    # Push to trigger deployment
    if [ "$ENVIRONMENT" = "staging" ]; then
        echo "🚀 Pushing to main branch (will trigger automatic staging deployment)..."
        git push origin main
        echo ""
        echo "✅ Staging deployment triggered!"
        echo "🔗 Monitor progress: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null || echo 'your-org/your-repo')/actions"
    else
        echo "📋 Changes pushed. For production deployment:"
        echo "1. Go to Actions tab: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name' 2>/dev/null || echo 'your-org/your-repo')/actions"
        echo "2. Run 'Search Sonar Infrastructure CI/CD' workflow"
        echo "3. Select Environment: $ENVIRONMENT, Action: apply"
        git push origin main
    fi
else
    echo "❌ Deployment cancelled. Restoring backup..."
    mv "$TFVARS_FILE.backup" "$TFVARS_FILE"
    echo "✅ Backup restored"
fi

echo ""
echo "🎉 Script completed!"

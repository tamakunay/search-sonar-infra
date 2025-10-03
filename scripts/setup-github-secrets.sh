#!/bin/bash

# Setup GitHub Secrets for Search Sonar Infrastructure
# This script helps you set up the required GitHub secrets for CI/CD

set -e

echo "🔐 Search Sonar Infrastructure - GitHub Secrets Setup"
echo "=================================================="
echo ""

# Check if GitHub CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ GitHub CLI (gh) is not installed."
    echo "Please install it from: https://cli.github.com/"
    echo ""
    echo "On macOS: brew install gh"
    echo "On Ubuntu: sudo apt install gh"
    exit 1
fi

# Check if user is authenticated
if ! gh auth status &> /dev/null; then
    echo "❌ You are not authenticated with GitHub CLI."
    echo "Please run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI is installed and authenticated"
echo ""

# Get current AWS credentials
echo "🔍 Detecting current AWS credentials..."
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id 2>/dev/null || echo "")
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key 2>/dev/null || echo "")
AWS_REGION=$(aws configure get region 2>/dev/null || echo "ap-southeast-1")

if [ -z "$AWS_ACCESS_KEY_ID" ] || [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    echo "❌ AWS credentials not found in AWS CLI configuration."
    echo "Please run: aws configure"
    echo "Or set the following environment variables:"
    echo "  export AWS_ACCESS_KEY_ID=your_access_key"
    echo "  export AWS_SECRET_ACCESS_KEY=your_secret_key"
    exit 1
fi

echo "✅ AWS credentials detected"
echo "   Region: $AWS_REGION"
echo "   Access Key: ${AWS_ACCESS_KEY_ID:0:8}..."
echo ""

# Confirm with user
echo "🚀 Ready to set up GitHub secrets for this repository."
echo ""
read -p "Do you want to continue? (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Setup cancelled."
    exit 1
fi

echo ""
echo "📝 Setting up GitHub secrets..."

# Set the secrets
echo "Setting AWS_ACCESS_KEY_ID..."
echo "$AWS_ACCESS_KEY_ID" | gh secret set AWS_ACCESS_KEY_ID

echo "Setting AWS_SECRET_ACCESS_KEY..."
echo "$AWS_SECRET_ACCESS_KEY" | gh secret set AWS_SECRET_ACCESS_KEY

echo "Setting AWS_REGION..."
echo "$AWS_REGION" | gh secret set AWS_REGION

echo ""
echo "✅ GitHub secrets have been set successfully!"
echo ""

# Check if environments exist
echo "🌍 Checking GitHub environments..."
echo ""

# Note: GitHub CLI doesn't have direct environment management
# So we'll provide instructions instead
echo "📋 Next Steps - Set up GitHub Environments:"
echo ""
echo "1. Go to your repository on GitHub.com"
echo "2. Navigate to Settings > Environments"
echo "3. Create the following environments:"
echo ""
echo "   📦 staging"
echo "      - No protection rules needed"
echo "      - Used for automatic deployments from main branch"
echo ""
echo "   📦 production"
echo "      - Add protection rules:"
echo "        ✓ Required reviewers (recommended)"
echo "        ✓ Restrict pushes to protected branches"
echo "      - Used for manual production deployments"
echo ""
echo "   📦 staging-destroy (optional)"
echo "      - Add protection rules if desired"
echo "      - Used for destroying staging infrastructure"
echo ""
echo "   📦 production-destroy (recommended)"
echo "      - Add protection rules:"
echo "        ✓ Required reviewers (strongly recommended)"
echo "      - Used for destroying production infrastructure"
echo ""

echo "🎯 Quick Links:"
echo "   Repository Settings: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name")/settings"
echo "   Environments: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name")/settings/environments"
echo "   Actions: https://github.com/$(gh repo view --json owner,name -q '.owner.login + "/" + .name")/actions"
echo ""

echo "🚀 Setup Complete!"
echo ""
echo "You can now:"
echo "1. Create a Pull Request to test the validation workflow"
echo "2. Push to main branch to deploy to staging automatically"
echo "3. Use 'Actions' tab for manual deployments"
echo ""
echo "📚 For detailed usage instructions, see: docs/github-actions.md"

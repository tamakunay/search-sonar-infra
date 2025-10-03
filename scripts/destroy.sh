#!/bin/bash

# Search Sonar Infrastructure Destroy Script
# Usage: ./scripts/destroy.sh [environment]
# Example: ./scripts/destroy.sh staging

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-staging}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(production|staging)$ ]]; then
    echo -e "${RED}Error: Environment must be 'production' or 'staging'${NC}"
    echo "Usage: $0 [environment]"
    exit 1
fi

# Set working directory
WORK_DIR="environments/$ENVIRONMENT"

echo -e "${RED}🗑️  Search Sonar Infrastructure Destroy${NC}"
echo -e "${RED}Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "${RED}Working Directory: ${YELLOW}$WORK_DIR${NC}"
echo ""

# Extra warnings for production
if [[ "$ENVIRONMENT" == "production" ]]; then
    echo -e "${RED}⚠️  ⚠️  ⚠️  WARNING: PRODUCTION ENVIRONMENT ⚠️  ⚠️  ⚠️${NC}"
    echo -e "${RED}This will destroy ALL production resources including:${NC}"
    echo -e "${RED}- Database with all data${NC}"
    echo -e "${RED}- Redis cache${NC}"
    echo -e "${RED}- ECS services${NC}"
    echo -e "${RED}- Load balancer${NC}"
    echo -e "${RED}- Frontend deployment${NC}"
    echo -e "${RED}- All monitoring and logs${NC}"
    echo ""
fi

# Multiple confirmations
echo -e "${RED}⚠️  This will PERMANENTLY DELETE all resources in the $ENVIRONMENT environment!${NC}"
echo -e "${RED}This action CANNOT be undone!${NC}"
echo ""

read -p "Are you absolutely sure you want to destroy the $ENVIRONMENT environment? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Destroy cancelled${NC}"
    exit 0
fi

echo ""
read -p "Type the environment name '$ENVIRONMENT' to confirm: " -r
if [[ ! $REPLY == "$ENVIRONMENT" ]]; then
    echo -e "${YELLOW}Destroy cancelled - environment name mismatch${NC}"
    exit 0
fi

echo ""
read -p "Type 'DESTROY' in capital letters to proceed: " -r
if [[ ! $REPLY == "DESTROY" ]]; then
    echo -e "${YELLOW}Destroy cancelled${NC}"
    exit 0
fi

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    exit 1
fi

# Change to environment directory
cd "$WORK_DIR"

echo ""
echo -e "${RED}🚀 Starting destruction process...${NC}"
echo ""

# Show what will be destroyed
echo -e "${BLUE}Resources that will be destroyed:${NC}"
terraform plan -destroy

echo ""
echo -e "${RED}Last chance to cancel!${NC}"
read -p "Proceed with destruction? (yes/no): " -r
if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    echo -e "${YELLOW}Destroy cancelled${NC}"
    exit 0
fi

# Execute destroy
echo -e "${RED}🗑️  Destroying resources...${NC}"
if terraform destroy -auto-approve; then
    echo -e "${GREEN}✅ Resources destroyed successfully${NC}"
else
    echo -e "${RED}❌ Destroy failed${NC}"
    echo -e "${YELLOW}You may need to manually clean up some resources${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Destruction completed successfully!${NC}"
echo -e "${BLUE}All resources in the $ENVIRONMENT environment have been destroyed.${NC}"

# Cleanup terraform state (optional)
echo ""
read -p "Do you want to remove the Terraform state files? (yes/no): " -r
if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
    rm -rf .terraform
    rm -f terraform.tfstate*
    echo -e "${GREEN}✅ Terraform state files removed${NC}"
fi

echo -e "${GREEN}✨ Cleanup completed!${NC}"
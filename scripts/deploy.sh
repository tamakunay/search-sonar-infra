#!/bin/bash

# Search Sonar Infrastructure Deployment Script
# Usage: ./scripts/deploy.sh [environment] [action]
# Example: ./scripts/deploy.sh production plan
# Example: ./scripts/deploy.sh staging apply

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-staging}
ACTION=${2:-plan}

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(production|staging)$ ]]; then
    echo -e "${RED}Error: Environment must be 'production' or 'staging'${NC}"
    echo "Usage: $0 [environment] [action]"
    exit 1
fi

# Validate action
if [[ ! "$ACTION" =~ ^(plan|apply|destroy|init|validate|output)$ ]]; then
    echo -e "${RED}Error: Action must be one of: plan, apply, destroy, init, validate, output${NC}"
    echo "Usage: $0 [environment] [action]"
    exit 1
fi

# Set working directory
WORK_DIR="environments/$ENVIRONMENT"

echo -e "${BLUE}🚀 Search Sonar Infrastructure Deployment${NC}"
echo -e "${BLUE}Environment: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "${BLUE}Action: ${YELLOW}$ACTION${NC}"
echo -e "${BLUE}Working Directory: ${YELLOW}$WORK_DIR${NC}"
echo ""

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}Error: Terraform is not installed${NC}"
    echo "Please install Terraform: https://www.terraform.io/downloads.html"
    exit 1
fi

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}Error: AWS credentials not configured${NC}"
    echo "Please configure AWS credentials: aws configure"
    exit 1
fi

# Change to environment directory
cd "$WORK_DIR"

# Function to run terraform command with proper error handling
run_terraform() {
    local cmd="$1"
    echo -e "${BLUE}Running: terraform $cmd${NC}"

    if terraform $cmd; then
        echo -e "${GREEN}✅ terraform $cmd completed successfully${NC}"
    else
        echo -e "${RED}❌ terraform $cmd failed${NC}"
        exit 1
    fi
}

# Execute based on action
case $ACTION in
    init)
        echo -e "${YELLOW}🔧 Initializing Terraform...${NC}"
        run_terraform "init"
        ;;

    validate)
        echo -e "${YELLOW}🔍 Validating Terraform configuration...${NC}"
        run_terraform "validate"
        ;;

    plan)
        echo -e "${YELLOW}📋 Planning Terraform changes...${NC}"
        run_terraform "plan"
        ;;

    apply)
        echo -e "${YELLOW}🚀 Applying Terraform changes...${NC}"

        # Show plan first
        echo -e "${BLUE}Showing plan before apply...${NC}"
        terraform plan

        # Confirmation for production
        if [[ "$ENVIRONMENT" == "production" ]]; then
            echo -e "${RED}⚠️  WARNING: You are about to apply changes to PRODUCTION!${NC}"
            read -p "Are you sure you want to continue? (yes/no): " -r
            if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
                echo -e "${YELLOW}Deployment cancelled${NC}"
                exit 0
            fi
        fi

        run_terraform "apply -auto-approve"

        echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
        echo -e "${BLUE}Getting outputs...${NC}"
        terraform output
        ;;

    destroy)
        echo -e "${RED}🗑️  Destroying Terraform resources...${NC}"

        # Extra confirmation for destroy
        echo -e "${RED}⚠️  WARNING: This will DESTROY all resources in $ENVIRONMENT!${NC}"
        read -p "Type 'destroy' to confirm: " -r
        if [[ ! $REPLY == "destroy" ]]; then
            echo -e "${YELLOW}Destroy cancelled${NC}"
            exit 0
        fi

        run_terraform "destroy -auto-approve"
        echo -e "${GREEN}✅ Resources destroyed successfully${NC}"
        ;;

    output)
        echo -e "${YELLOW}📊 Getting Terraform outputs...${NC}"
        terraform output
        ;;
esac

echo -e "${GREEN}✨ Script completed successfully!${NC}"
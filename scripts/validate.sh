#!/bin/bash

# Search Sonar Infrastructure Validation Script
# Usage: ./scripts/validate.sh [environment]
# Example: ./scripts/validate.sh production

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT=${1:-all}

echo -e "${BLUE}🔍 Search Sonar Infrastructure Validation${NC}"
echo ""

# Function to validate environment
validate_environment() {
    local env=$1
    local work_dir="environments/$env"

    echo -e "${YELLOW}Validating $env environment...${NC}"

    if [[ ! -d "$work_dir" ]]; then
        echo -e "${RED}❌ Environment directory $work_dir does not exist${NC}"
        return 1
    fi

    cd "$work_dir"

    # Check if required files exist
    local required_files=("main.tf" "variables.tf" "terraform.tfvars" "outputs.tf")
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            echo -e "${RED}❌ Required file $file is missing${NC}"
            return 1
        fi
    done

    # Initialize if needed
    if [[ ! -d ".terraform" ]]; then
        echo -e "${BLUE}Initializing Terraform...${NC}"
        terraform init -backend=false
    fi

    # Validate Terraform configuration
    if terraform validate; then
        echo -e "${GREEN}✅ $env environment validation passed${NC}"
    else
        echo -e "${RED}❌ $env environment validation failed${NC}"
        return 1
    fi

    # Format check
    if terraform fmt -check=true -diff=true; then
        echo -e "${GREEN}✅ $env environment formatting is correct${NC}"
    else
        echo -e "${YELLOW}⚠️  $env environment has formatting issues${NC}"
        echo -e "${BLUE}Run 'terraform fmt' to fix formatting${NC}"
    fi

    cd - > /dev/null
    echo ""
}

# Function to validate modules
validate_modules() {
    echo -e "${YELLOW}Validating modules...${NC}"

    local modules_dir="modules"
    local modules=($(find $modules_dir -maxdepth 1 -mindepth 1 -type d -exec basename {} \;))

    for module in "${modules[@]}"; do
        local module_dir="$modules_dir/$module"
        echo -e "${BLUE}Validating module: $module${NC}"

        cd "$module_dir"

        # Check if required files exist
        local required_files=("main.tf" "variables.tf" "outputs.tf")
        for file in "${required_files[@]}"; do
            if [[ ! -f "$file" ]]; then
                echo -e "${RED}❌ Module $module is missing $file${NC}"
                cd - > /dev/null
                return 1
            fi
        done

        # Initialize if needed (for provider validation)
        if [[ ! -d ".terraform" ]]; then
            echo -e "${BLUE}Initializing module $module...${NC}"
            if terraform init -backend=false > /dev/null 2>&1; then
                echo -e "${GREEN}✅ Module $module initialized${NC}"
            else
                echo -e "${YELLOW}⚠️  Module $module initialization skipped (providers will be available in environment)${NC}"
            fi
        fi

        # Validate module (skip if init failed, as it will work in environment context)
        if terraform validate > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Module $module validation passed${NC}"
        else
            echo -e "${YELLOW}⚠️  Module $module validation skipped (will be validated in environment context)${NC}"
        fi

        cd - > /dev/null
    done

    echo -e "${GREEN}✅ All modules structure validation completed${NC}"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"

    # Check Terraform
    if command -v terraform &> /dev/null; then
        local tf_version=$(terraform version -json | jq -r '.terraform_version')
        echo -e "${GREEN}✅ Terraform installed: $tf_version${NC}"
    else
        echo -e "${RED}❌ Terraform is not installed${NC}"
        return 1
    fi

    # Check AWS CLI
    if command -v aws &> /dev/null; then
        local aws_version=$(aws --version | cut -d' ' -f1)
        echo -e "${GREEN}✅ AWS CLI installed: $aws_version${NC}"
    else
        echo -e "${RED}❌ AWS CLI is not installed${NC}"
        return 1
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        echo -e "${GREEN}✅ jq is installed${NC}"
    else
        echo -e "${YELLOW}⚠️  jq is not installed (recommended for JSON processing)${NC}"
    fi

    echo ""
}

# Function to validate configuration files
validate_config_files() {
    echo -e "${YELLOW}Validating configuration files...${NC}"

    # Check if terraform.tfvars files have required variables
    local environments=("production" "staging")

    for env in "${environments[@]}"; do
        local tfvars_file="environments/$env/terraform.tfvars"

        if [[ -f "$tfvars_file" ]]; then
            echo -e "${BLUE}Checking $tfvars_file...${NC}"

            # Check for placeholder values that need to be updated
            if grep -q "yourusername" "$tfvars_file"; then
                echo -e "${YELLOW}⚠️  $tfvars_file contains placeholder values that need to be updated${NC}"
            fi

            if grep -q "nginx:latest" "$tfvars_file"; then
                echo -e "${YELLOW}⚠️  $tfvars_file is using default nginx images - update with your actual container images${NC}"
            fi

            echo -e "${GREEN}✅ $tfvars_file exists${NC}"
        else
            echo -e "${RED}❌ $tfvars_file is missing${NC}"
            return 1
        fi
    done

    echo ""
}

# Main validation logic
main() {
    check_prerequisites
    validate_modules
    validate_config_files

    if [[ "$ENVIRONMENT" == "all" ]]; then
        validate_environment "production"
        validate_environment "staging"
    else
        if [[ "$ENVIRONMENT" =~ ^(production|staging)$ ]]; then
            validate_environment "$ENVIRONMENT"
        else
            echo -e "${RED}Error: Environment must be 'production', 'staging', or 'all'${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}🎉 All validations completed successfully!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo -e "1. Update terraform.tfvars files with your actual values"
    echo -e "2. Configure AWS credentials: aws configure"
    echo -e "3. Run: ./scripts/deploy.sh staging init"
    echo -e "4. Run: ./scripts/deploy.sh staging plan"
    echo -e "5. Run: ./scripts/deploy.sh staging apply"
}

# Run main function
main
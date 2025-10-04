#!/bin/bash

# Status checker for Search Sonar infrastructure cleanup
# This script checks the status of resources that may still be deleting

set -e

ENVIRONMENT="${1:-staging}"
AWS_REGION="ap-southeast-1"
PROJECT_NAME="search-sonar"
PATTERN="$PROJECT_NAME-$ENVIRONMENT"

echo "🔍 Checking cleanup status for Search Sonar"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Pattern: $PATTERN"
echo ""

# Function to check resource status
check_resource_status() {
    local resource_type="$1"
    local check_command="$2"
    local resource_name="$3"
    
    echo -n "📋 $resource_type: "
    if result=$(eval "$check_command" 2>/dev/null); then
        if [ -n "$result" ] && [ "$result" != "None" ] && [ "$result" != "null" ]; then
            echo "🟡 Still exists ($result)"
            return 1
        else
            echo "✅ Deleted"
            return 0
        fi
    else
        echo "✅ Deleted"
        return 0
    fi
}

# Function to check multiple resources by pattern
check_resources_by_pattern() {
    local service="$1"
    local resource_type="$2"
    local pattern="$3"
    local list_command="$4"
    
    echo -n "📋 $resource_type: "
    if resources=$(eval "$list_command" 2>/dev/null); then
        if [ -n "$resources" ] && [ "$resources" != "None" ] && [ "$resources" != "null" ]; then
            count=$(echo "$resources" | wc -w | tr -d ' ')
            echo "🟡 $count still exist"
            echo "$resources" | tr ' ' '\n' | sed 's/^/    - /'
            return 1
        else
            echo "✅ All deleted"
            return 0
        fi
    else
        echo "✅ All deleted"
        return 0
    fi
}

echo "🔍 Checking individual resources..."

# Check RDS instance
check_resource_status "RDS Instance" \
    "aws rds describe-db-instances --db-instance-identifier $PATTERN-postgres --region $AWS_REGION --query 'DBInstances[0].DBInstanceStatus' --output text" \
    "$PATTERN-postgres"

# Check ElastiCache cluster
check_resource_status "ElastiCache Cluster" \
    "aws elasticache describe-replication-groups --replication-group-id $PATTERN-redis --region $AWS_REGION --query 'ReplicationGroups[0].Status' --output text" \
    "$PATTERN-redis"

# Check Load Balancer
check_resource_status "Load Balancer" \
    "aws elbv2 describe-load-balancers --names $PATTERN-alb --region $AWS_REGION --query 'LoadBalancers[0].State.Code' --output text" \
    "$PATTERN-alb"

echo ""
echo "🔍 Checking resource groups..."

# Check ECS Services
check_resources_by_pattern "ecs-services" "ECS Services" "$PATTERN" \
    "aws ecs list-clusters --region $AWS_REGION --query \"clusterArns[?contains(@, '$PATTERN')]\" --output text | tr '\t' '\n' | while read -r cluster_arn; do if [ -n \"\$cluster_arn\" ]; then cluster_name=\$(basename \"\$cluster_arn\"); aws ecs list-services --cluster \"\$cluster_name\" --region $AWS_REGION --query 'serviceArns[]' --output text; fi; done"

# Check ECS Clusters
check_resources_by_pattern "ecs-clusters" "ECS Clusters" "$PATTERN" \
    "aws ecs list-clusters --region $AWS_REGION --query \"clusterArns[?contains(@, '$PATTERN')]\" --output text"

# Check Target Groups
check_resources_by_pattern "target-groups" "Target Groups" "$PATTERN" \
    "aws elbv2 describe-target-groups --region $AWS_REGION --query \"TargetGroups[?contains(TargetGroupName, '$PATTERN')].TargetGroupName\" --output text"

# Check RDS Parameter Groups
check_resources_by_pattern "rds-parameter-groups" "RDS Parameter Groups" "$PATTERN" \
    "aws rds describe-db-parameter-groups --region $AWS_REGION --query \"DBParameterGroups[?contains(DBParameterGroupName, '$PATTERN')].DBParameterGroupName\" --output text"

# Check RDS Option Groups
check_resources_by_pattern "rds-option-groups" "RDS Option Groups" "$PATTERN" \
    "aws rds describe-option-groups --region $AWS_REGION --query \"OptionGroupsList[?contains(OptionGroupName, '$PATTERN')].OptionGroupName\" --output text"

# Check RDS Subnet Groups
check_resources_by_pattern "rds-subnet-groups" "RDS Subnet Groups" "$PATTERN" \
    "aws rds describe-db-subnet-groups --region $AWS_REGION --query \"DBSubnetGroups[?contains(DBSubnetGroupName, '$PATTERN')].DBSubnetGroupName\" --output text"

# Check ElastiCache Parameter Groups
check_resources_by_pattern "elasticache-parameter-groups" "ElastiCache Parameter Groups" "$PATTERN" \
    "aws elasticache describe-cache-parameter-groups --region $AWS_REGION --query \"CacheParameterGroups[?contains(CacheParameterGroupName, '$PATTERN')].CacheParameterGroupName\" --output text"

# Check ElastiCache Subnet Groups
check_resources_by_pattern "elasticache-subnet-groups" "ElastiCache Subnet Groups" "$PATTERN" \
    "aws elasticache describe-cache-subnet-groups --region $AWS_REGION --query \"CacheSubnetGroups[?contains(CacheSubnetGroupName, '$PATTERN')].CacheSubnetGroupName\" --output text"

# Check Secrets Manager secrets
check_resources_by_pattern "secrets" "Secrets Manager Secrets" "$PATTERN" \
    "aws secretsmanager list-secrets --region $AWS_REGION --query \"SecretList[?contains(Name, '$PATTERN')].Name\" --output text"

# Check SNS Topics
check_resources_by_pattern "sns-topics" "SNS Topics" "$PATTERN" \
    "aws sns list-topics --region $AWS_REGION --query \"Topics[?contains(TopicArn, '$PATTERN')].TopicArn\" --output text"

# Check Amplify Apps
check_resources_by_pattern "amplify-apps" "Amplify Apps" "$PATTERN" \
    "aws amplify list-apps --region $AWS_REGION --query \"apps[?contains(name, '$PATTERN')].name\" --output text"

echo ""
echo "🏁 Status check completed!"
echo ""
echo "Legend:"
echo "  ✅ = Resource deleted/not found"
echo "  🟡 = Resource still exists (may be deleting)"
echo ""
echo "💡 If all resources show ✅, you can proceed with deployment"
echo "💡 If some show 🟡, wait a few minutes and run this script again"

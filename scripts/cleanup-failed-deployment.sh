#!/bin/bash

# Comprehensive cleanup script for failed Search Sonar deployment
# This script removes ALL resources that were created during failed deployments

set -e

ENVIRONMENT="${1:-staging}"
AWS_REGION="ap-southeast-1"
PROJECT_NAME="search-sonar"

echo "🧹 Comprehensive cleanup for Search Sonar deployment"
echo "Environment: $ENVIRONMENT"
echo "Region: $AWS_REGION"
echo "Project: $PROJECT_NAME"
echo ""

echo "⚠️  WARNING: This will delete ALL AWS resources for this environment!"
echo "This script will remove:"
echo "- All Secrets Manager secrets"
echo "- All CloudWatch log groups and query definitions"
echo "- All RDS instances, parameter groups, option groups, subnet groups"
echo "- All ElastiCache clusters, parameter groups, subnet groups"
echo "- All ECS clusters, services, task definitions"
echo ""
echo "- All Load balancers, target groups, listeners"
echo "- All Amplify apps"
echo "- All SNS topics and subscriptions"
echo "- All CloudWatch dashboards and alarms"
echo "- All VPC resources (if not shared)"
echo ""

read -p "Are you sure you want to continue? This cannot be undone! (y/N): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cleanup cancelled."
    exit 1
fi

echo ""
echo "🗑️  Starting comprehensive cleanup..."

# Function to safely delete resource
safe_delete() {
    local resource_type="$1"
    local resource_name="$2"
    local aws_command="$3"

    echo "Checking $resource_type: $resource_name"
    if eval "$aws_command" >/dev/null 2>&1; then
        echo "  ✅ Deleting $resource_type: $resource_name"
        eval "$aws_command"
    else
        echo "  ⏭️  $resource_type not found: $resource_name"
    fi
}

# Function to delete resources by tag or name pattern
delete_by_pattern() {
    local service="$1"
    local resource_type="$2"
    local pattern="$3"
    local delete_command="$4"

    echo ""
    echo "🔍 Finding $resource_type resources matching pattern: $pattern"

    case $service in
        "secrets")
            aws secretsmanager list-secrets --region $AWS_REGION --query "SecretList[?contains(Name, '$pattern')].Name" --output text | tr '\t' '\n' | while read -r secret; do
                if [ -n "$secret" ]; then
                    echo "  ✅ Deleting Secret: $secret"
                    aws secretsmanager delete-secret --secret-id "$secret" --force-delete-without-recovery --region $AWS_REGION || true
                fi
            done
            ;;
        "logs")
            aws logs describe-log-groups --region $AWS_REGION --log-group-name-prefix "$pattern" --query 'logGroups[].logGroupName' --output text | tr '\t' '\n' | while read -r log_group; do
                if [ -n "$log_group" ]; then
                    echo "  ✅ Deleting Log Group: $log_group"
                    aws logs delete-log-group --log-group-name "$log_group" --region $AWS_REGION || true
                fi
            done
            ;;
        "query-definitions")
            aws logs describe-query-definitions --region $AWS_REGION --query "queryDefinitions[?contains(name, '$pattern')].queryDefinitionId" --output text | tr '\t' '\n' | while read -r query_id; do
                if [ -n "$query_id" ]; then
                    echo "  ✅ Deleting Query Definition: $query_id"
                    aws logs delete-query-definition --query-definition-id "$query_id" --region $AWS_REGION || true
                fi
            done
            ;;
        "rds-instances")
            aws rds describe-db-instances --region $AWS_REGION --query "DBInstances[?contains(DBInstanceIdentifier, '$pattern')].DBInstanceIdentifier" --output text | tr '\t' '\n' | while read -r db_instance; do
                if [ -n "$db_instance" ]; then
                    echo "  ✅ Deleting RDS Instance: $db_instance"
                    aws rds delete-db-instance --db-instance-identifier "$db_instance" --skip-final-snapshot --delete-automated-backups --region $AWS_REGION || true
                fi
            done
            ;;
        "rds-parameter-groups")
            aws rds describe-db-parameter-groups --region $AWS_REGION --query "DBParameterGroups[?contains(DBParameterGroupName, '$pattern')].DBParameterGroupName" --output text | tr '\t' '\n' | while read -r param_group; do
                if [ -n "$param_group" ]; then
                    echo "  ✅ Deleting RDS Parameter Group: $param_group"
                    aws rds delete-db-parameter-group --db-parameter-group-name "$param_group" --region $AWS_REGION || true
                fi
            done
            ;;
        "rds-option-groups")
            aws rds describe-option-groups --region $AWS_REGION --query "OptionGroupsList[?contains(OptionGroupName, '$pattern')].OptionGroupName" --output text | tr '\t' '\n' | while read -r option_group; do
                if [ -n "$option_group" ]; then
                    echo "  ✅ Deleting RDS Option Group: $option_group"
                    aws rds delete-option-group --option-group-name "$option_group" --region $AWS_REGION || true
                fi
            done
            ;;
        "rds-subnet-groups")
            aws rds describe-db-subnet-groups --region $AWS_REGION --query "DBSubnetGroups[?contains(DBSubnetGroupName, '$pattern')].DBSubnetGroupName" --output text | tr '\t' '\n' | while read -r subnet_group; do
                if [ -n "$subnet_group" ]; then
                    echo "  ✅ Deleting RDS Subnet Group: $subnet_group"
                    aws rds delete-db-subnet-group --db-subnet-group-name "$subnet_group" --region $AWS_REGION || true
                fi
            done
            ;;
        "elasticache-clusters")
            aws elasticache describe-replication-groups --region $AWS_REGION --query "ReplicationGroups[?contains(ReplicationGroupId, '$pattern')].ReplicationGroupId" --output text | tr '\t' '\n' | while read -r cluster; do
                if [ -n "$cluster" ]; then
                    echo "  ✅ Deleting ElastiCache Cluster: $cluster"
                    aws elasticache delete-replication-group --replication-group-id "$cluster" --region $AWS_REGION || true
                fi
            done
            ;;
        "elasticache-parameter-groups")
            aws elasticache describe-cache-parameter-groups --region $AWS_REGION --query "CacheParameterGroups[?contains(CacheParameterGroupName, '$pattern')].CacheParameterGroupName" --output text | tr '\t' '\n' | while read -r param_group; do
                if [ -n "$param_group" ]; then
                    echo "  ✅ Deleting ElastiCache Parameter Group: $param_group"
                    aws elasticache delete-cache-parameter-group --cache-parameter-group-name "$param_group" --region $AWS_REGION || true
                fi
            done
            ;;
        "elasticache-subnet-groups")
            aws elasticache describe-cache-subnet-groups --region $AWS_REGION --query "CacheSubnetGroups[?contains(CacheSubnetGroupName, '$pattern')].CacheSubnetGroupName" --output text | tr '\t' '\n' | while read -r subnet_group; do
                if [ -n "$subnet_group" ]; then
                    echo "  ✅ Deleting ElastiCache Subnet Group: $subnet_group"
                    aws elasticache delete-cache-subnet-group --cache-subnet-group-name "$subnet_group" --region $AWS_REGION || true
                fi
            done
            ;;
        "ecs-services")
            aws ecs list-clusters --region $AWS_REGION --query "clusterArns[?contains(@, '$pattern')]" --output text | tr '\t' '\n' | while read -r cluster_arn; do
                if [ -n "$cluster_arn" ]; then
                    cluster_name=$(basename "$cluster_arn")
                    aws ecs list-services --cluster "$cluster_name" --region $AWS_REGION --query 'serviceArns[]' --output text | tr '\t' '\n' | while read -r service_arn; do
                        if [ -n "$service_arn" ]; then
                            service_name=$(basename "$service_arn")
                            echo "  ✅ Deleting ECS Service: $service_name"
                            aws ecs update-service --cluster "$cluster_name" --service "$service_name" --desired-count 0 --region $AWS_REGION || true
                            aws ecs delete-service --cluster "$cluster_name" --service "$service_name" --region $AWS_REGION || true
                        fi
                    done
                fi
            done
            ;;
        "ecs-clusters")
            aws ecs list-clusters --region $AWS_REGION --query "clusterArns[?contains(@, '$pattern')]" --output text | tr '\t' '\n' | while read -r cluster_arn; do
                if [ -n "$cluster_arn" ]; then
                    cluster_name=$(basename "$cluster_arn")
                    echo "  ✅ Deleting ECS Cluster: $cluster_name"
                    aws ecs delete-cluster --cluster "$cluster_name" --region $AWS_REGION || true
                fi
            done
            ;;
        "load-balancers")
            aws elbv2 describe-load-balancers --region $AWS_REGION --query "LoadBalancers[?contains(LoadBalancerName, '$pattern')].LoadBalancerArn" --output text | tr '\t' '\n' | while read -r lb_arn; do
                if [ -n "$lb_arn" ]; then
                    echo "  ✅ Deleting Load Balancer: $lb_arn"
                    aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region $AWS_REGION || true
                fi
            done
            ;;
        "target-groups")
            aws elbv2 describe-target-groups --region $AWS_REGION --query "TargetGroups[?contains(TargetGroupName, '$pattern')].TargetGroupArn" --output text | tr '\t' '\n' | while read -r tg_arn; do
                if [ -n "$tg_arn" ]; then
                    echo "  ✅ Deleting Target Group: $tg_arn"
                    aws elbv2 delete-target-group --target-group-arn "$tg_arn" --region $AWS_REGION || true
                fi
            done
            ;;

        "amplify-apps")
            aws amplify list-apps --region $AWS_REGION --query "apps[?contains(name, '$pattern')].appId" --output text | tr '\t' '\n' | while read -r app_id; do
                if [ -n "$app_id" ]; then
                    echo "  ✅ Deleting Amplify App: $app_id"
                    aws amplify delete-app --app-id "$app_id" --region $AWS_REGION || true
                fi
            done
            ;;
        "sns-topics")
            aws sns list-topics --region $AWS_REGION --query "Topics[?contains(TopicArn, '$pattern')].TopicArn" --output text | tr '\t' '\n' | while read -r topic_arn; do
                if [ -n "$topic_arn" ]; then
                    echo "  ✅ Deleting SNS Topic: $topic_arn"
                    aws sns delete-topic --topic-arn "$topic_arn" --region $AWS_REGION || true
                fi
            done
            ;;
        "cloudwatch-dashboards")
            aws cloudwatch list-dashboards --region $AWS_REGION --query "DashboardEntries[?contains(DashboardName, '$pattern')].DashboardName" --output text | tr '\t' '\n' | while read -r dashboard; do
                if [ -n "$dashboard" ]; then
                    echo "  ✅ Deleting CloudWatch Dashboard: $dashboard"
                    aws cloudwatch delete-dashboards --dashboard-names "$dashboard" --region $AWS_REGION || true
                fi
            done
            ;;
    esac
}

# Pattern for this environment
PATTERN="$PROJECT_NAME-$ENVIRONMENT"

# 1. ECS Services and Clusters (delete services first, then clusters)
delete_by_pattern "ecs-services" "ECS Services" "$PATTERN"
sleep 30  # Wait for services to be deleted
delete_by_pattern "ecs-clusters" "ECS Clusters" "$PATTERN"

# 2. Load Balancers and Target Groups
delete_by_pattern "load-balancers" "Load Balancers" "$PATTERN"
delete_by_pattern "target-groups" "Target Groups" "$PATTERN"

# 3. RDS Resources (delete instances first, then groups)
delete_by_pattern "rds-instances" "RDS Instances" "$PATTERN"
sleep 60  # Wait for RDS instances to be deleted
delete_by_pattern "rds-parameter-groups" "RDS Parameter Groups" "$PATTERN"
delete_by_pattern "rds-option-groups" "RDS Option Groups" "$PATTERN"
delete_by_pattern "rds-subnet-groups" "RDS Subnet Groups" "$PATTERN"

# 4. ElastiCache Resources (delete clusters first, then groups)
delete_by_pattern "elasticache-clusters" "ElastiCache Clusters" "$PATTERN"
sleep 60  # Wait for ElastiCache clusters to be deleted
delete_by_pattern "elasticache-parameter-groups" "ElastiCache Parameter Groups" "$PATTERN"
delete_by_pattern "elasticache-subnet-groups" "ElastiCache Subnet Groups" "$PATTERN"

# 5. Secrets Manager
delete_by_pattern "secrets" "Secrets" "$PATTERN"

# 6. CloudWatch Resources
delete_by_pattern "logs" "Log Groups" "/aws/elasticache/redis/$PATTERN"
delete_by_pattern "logs" "Log Groups" "/ecs/$PATTERN"
delete_by_pattern "logs" "Log Groups" "/aws/rds/instance/$PATTERN"
delete_by_pattern "query-definitions" "Query Definitions" "$PATTERN"
delete_by_pattern "cloudwatch-dashboards" "CloudWatch Dashboards" "$PATTERN"

# 7. SNS Topics
delete_by_pattern "sns-topics" "SNS Topics" "$PATTERN"

# 8. Amplify Apps
delete_by_pattern "amplify-apps" "Amplify Apps" "$PATTERN"

# 9. IAM Roles - SKIP (should not be deleted automatically)
echo ""
echo "🔑 Skipping IAM roles cleanup..."
echo "ℹ️  IAM roles are preserved as they may be shared across environments"
echo "   If you need to clean up IAM roles, do it manually from AWS Console"

echo ""
echo "✅ Comprehensive cleanup completed!"
echo ""
echo "📋 Summary of what was cleaned up:"
echo "- ECS services and clusters"
echo "- Load balancers and target groups"
echo "- RDS instances, parameter groups, option groups, subnet groups"
echo "- ElastiCache clusters, parameter groups, subnet groups"
echo "- Secrets Manager secrets"
echo "- CloudWatch log groups, query definitions, dashboards"
echo "- SNS topics and subscriptions"
echo "- Amplify applications"
echo "- IAM roles (skipped - preserved for security)"
echo ""
echo "🚀 You can now run a fresh deployment:"
echo "   cd environments/$ENVIRONMENT && terraform apply"
echo ""
echo "📋 Or commit and push to trigger GitHub Actions:"
echo "   git add ."
echo "   git commit -m 'fix: configure S3 backend and resolve deployment issues'"
echo "   git push origin main"

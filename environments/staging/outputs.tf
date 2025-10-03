# Networking Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = module.networking.private_subnet_ids
}

# Database Outputs
output "database_endpoint" {
  description = "RDS instance endpoint"
  value       = module.database.db_instance_address
  sensitive   = true
}

output "database_connection_secret_arn" {
  description = "ARN of the database connection secret"
  value       = module.database.db_connection_secret_arn
}

# Cache Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = module.cache.redis_primary_endpoint_address
  sensitive   = true
}

output "redis_connection_secret_arn" {
  description = "ARN of the Redis connection secret"
  value       = module.cache.redis_connection_secret_arn
}

# Load Balancer Outputs
output "load_balancer_dns_name" {
  description = "DNS name of the load balancer"
  value       = module.load_balancer.alb_dns_name
}

output "api_url" {
  description = "URL for the API"
  value       = module.load_balancer.api_url
}

# ECS Outputs
output "ecs_cluster_name" {
  description = "Name of the ECS cluster"
  value       = module.ecs_cluster.cluster_name
}

output "api_service_name" {
  description = "Name of the API ECS service"
  value       = module.ecs_cluster.api_service_name
}

output "worker_service_name" {
  description = "Name of the worker ECS service"
  value       = module.ecs_cluster.worker_service_name
}

# Frontend Outputs
output "frontend_url" {
  description = "URL of the frontend application"
  value       = module.frontend.custom_domain_url != null ? module.frontend.custom_domain_url : module.frontend.main_branch_url
}

output "amplify_app_id" {
  description = "Amplify App ID"
  value       = module.frontend.app_id
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = module.monitoring.dashboard_url
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = module.monitoring.sns_topic_arn
}
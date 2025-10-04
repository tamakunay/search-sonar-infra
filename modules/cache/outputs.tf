# Local values for Redis connection strings
locals {
  redis_endpoint           = aws_elasticache_replication_group.redis.configuration_endpoint_address != null && aws_elasticache_replication_group.redis.configuration_endpoint_address != "" ? aws_elasticache_replication_group.redis.configuration_endpoint_address : aws_elasticache_replication_group.redis.primary_endpoint_address
  redis_url_production     = var.environment == "production" ? "redis://:${random_password.redis_auth_token[0].result}@${local.redis_endpoint}:${aws_elasticache_replication_group.redis.port}" : "redis://${local.redis_endpoint}:${aws_elasticache_replication_group.redis.port}"
  redis_url_non_production = "redis://${local.redis_endpoint}:${aws_elasticache_replication_group.redis.port}"
}

output "redis_replication_group_id" {
  description = "ID of the ElastiCache replication group"
  value       = aws_elasticache_replication_group.redis.replication_group_id
}

output "redis_primary_endpoint_address" {
  description = "Address of the endpoint for the primary node in the replication group"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "redis_configuration_endpoint_address" {
  description = "Address of the replication group configuration endpoint when cluster mode is enabled"
  value       = aws_elasticache_replication_group.redis.configuration_endpoint_address
}

output "redis_port" {
  description = "Port number on which the cache nodes accept connections"
  value       = aws_elasticache_replication_group.redis.port
}

output "redis_auth_token_secret_arn" {
  description = "ARN of the secret containing the Redis auth token"
  value       = var.environment == "production" ? aws_secretsmanager_secret.redis_auth_token[0].arn : null
}

output "redis_connection_secret_arn" {
  description = "ARN of the secret containing the Redis connection details"
  value       = aws_secretsmanager_secret.redis_connection.arn
}

output "redis_connection_string" {
  description = "Redis connection string"
  value       = var.environment == "production" ? local.redis_url_production : local.redis_url_non_production
  sensitive   = true
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  family = "redis7"
  name   = "${var.name_prefix}-redis-params"

  # Optimize for BullMQ
  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  parameter {
    name  = "timeout"
    value = "300"
  }

  parameter {
    name  = "tcp-keepalive"
    value = "300"
  }

  # Enable keyspace notifications for BullMQ
  parameter {
    name  = "notify-keyspace-events"
    value = "Ex"
  }

  tags = var.common_tags
}

# ElastiCache Replication Group (Redis Cluster)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "${var.name_prefix}-redis"
  description          = "Redis cluster for ${var.name_prefix} BullMQ"

  # Node configuration
  node_type            = var.redis_node_type
  port                 = 6379
  parameter_group_name = aws_elasticache_parameter_group.redis.name

  # Cluster configuration
  num_cache_clusters = var.redis_num_cache_nodes

  # Engine
  engine_version = "7.0"

  # Network
  subnet_group_name  = var.cache_subnet_group_name
  security_group_ids = [var.redis_security_group_id]

  # Security
  at_rest_encryption_enabled = true
  transit_encryption_enabled = var.environment == "production"
  auth_token                 = var.environment == "production" ? random_password.redis_auth_token[0].result : null

  # Backup
  snapshot_retention_limit = var.environment == "production" ? 5 : 1
  snapshot_window          = "03:00-05:00"

  # Maintenance
  maintenance_window = "sun:05:00-sun:07:00"

  # Automatic failover
  automatic_failover_enabled = var.redis_num_cache_nodes > 1

  # Multi-AZ
  multi_az_enabled = var.environment == "production" && var.redis_num_cache_nodes > 1

  # Logging
  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.redis_slow.name
    destination_type = "cloudwatch-logs"
    log_format       = "text"
    log_type         = "slow-log"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-redis"
  })

  lifecycle {
    ignore_changes = [auth_token]
  }
}

# Random auth token for Redis (production only)
resource "random_password" "redis_auth_token" {
  count = var.environment == "production" ? 1 : 0

  length  = 32
  special = false
}

# Store Redis auth token in Secrets Manager (production only)
resource "aws_secretsmanager_secret" "redis_auth_token" {
  count = var.environment == "production" ? 1 : 0

  name                    = "${var.name_prefix}-redis-auth-token"
  description             = "Redis auth token for ${var.name_prefix}"
  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_auth_token" {
  count = var.environment == "production" ? 1 : 0

  secret_id = aws_secretsmanager_secret.redis_auth_token[0].id
  secret_string = jsonencode({
    auth_token = random_password.redis_auth_token[0].result
  })
}

# Redis connection details in Secrets Manager
resource "aws_secretsmanager_secret" "redis_connection" {
  name                    = "${var.name_prefix}-redis-connection"
  description             = "Redis connection details for ${var.name_prefix}"
  recovery_window_in_days = var.environment == "production" ? 30 : 0

  tags = var.common_tags
}

resource "aws_secretsmanager_secret_version" "redis_connection" {
  secret_id = aws_secretsmanager_secret.redis_connection.id
  secret_string = jsonencode({
    host       = aws_elasticache_replication_group.redis.configuration_endpoint_address != null && aws_elasticache_replication_group.redis.configuration_endpoint_address != "" ? aws_elasticache_replication_group.redis.configuration_endpoint_address : aws_elasticache_replication_group.redis.primary_endpoint_address
    port       = aws_elasticache_replication_group.redis.port
    auth_token = var.environment == "production" ? random_password.redis_auth_token[0].result : ""
    url        = var.environment == "production" ? "redis://:${random_password.redis_auth_token[0].result}@${aws_elasticache_replication_group.redis.configuration_endpoint_address != null && aws_elasticache_replication_group.redis.configuration_endpoint_address != "" ? aws_elasticache_replication_group.redis.configuration_endpoint_address : aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}" : "redis://${aws_elasticache_replication_group.redis.configuration_endpoint_address != null && aws_elasticache_replication_group.redis.configuration_endpoint_address != "" ? aws_elasticache_replication_group.redis.configuration_endpoint_address : aws_elasticache_replication_group.redis.primary_endpoint_address}:${aws_elasticache_replication_group.redis.port}"
  })
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "redis_slow" {
  name              = "/aws/elasticache/redis/${var.name_prefix}/slow-log"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = var.common_tags
}

# CloudWatch Alarms for Redis
resource "aws_cloudwatch_metric_alarm" "redis_cpu" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "${var.name_prefix}-redis-cpu-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redis cpu utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis.replication_group_id}-001"
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redis_memory" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "${var.name_prefix}-redis-memory-utilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "DatabaseMemoryUsagePercentage"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redis memory utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis.replication_group_id}-001"
  }

  tags = var.common_tags
}

resource "aws_cloudwatch_metric_alarm" "redis_connections" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "${var.name_prefix}-redis-current-connections"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CurrConnections"
  namespace           = "AWS/ElastiCache"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors redis current connections"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    CacheClusterId = "${aws_elasticache_replication_group.redis.replication_group_id}-001"
  }

  tags = var.common_tags
}

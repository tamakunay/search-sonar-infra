variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "alert_email" {
  description = "Email address for alerts"
  type        = string
  default     = ""
}

# ALB Variables
variable "alb_arn_suffix" {
  description = "ARN suffix of the Application Load Balancer"
  type        = string
}

variable "alb_target_response_time_alarm_name" {
  description = "Name of the ALB target response time alarm"
  type        = string
  default     = ""
}

variable "alb_healthy_host_count_alarm_name" {
  description = "Name of the ALB healthy host count alarm"
  type        = string
  default     = ""
}

variable "alb_http_5xx_count_alarm_name" {
  description = "Name of the ALB HTTP 5XX count alarm"
  type        = string
  default     = ""
}

# ECS Variables
variable "cluster_name" {
  description = "Name of the ECS cluster"
  type        = string
}

variable "api_service_name" {
  description = "Name of the API ECS service"
  type        = string
}

variable "worker_service_name" {
  description = "Name of the worker ECS service"
  type        = string
}

variable "api_log_group_name" {
  description = "Name of the API CloudWatch log group"
  type        = string
}

variable "worker_log_group_name" {
  description = "Name of the worker CloudWatch log group"
  type        = string
}

# Database Variables
variable "db_instance_id" {
  description = "ID of the RDS instance"
  type        = string
}

# Redis Variables
variable "redis_replication_group_id" {
  description = "ID of the Redis replication group"
  type        = string
}

variable "redis_cpu_alarm_name" {
  description = "Name of the Redis CPU alarm"
  type        = string
  default     = ""
}

variable "redis_memory_alarm_name" {
  description = "Name of the Redis memory alarm"
  type        = string
  default     = ""
}

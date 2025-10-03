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

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID for ECS tasks"
  type        = string
}

variable "db_connection_secret_arn" {
  description = "ARN of the database connection secret"
  type        = string
}

variable "redis_connection_secret_arn" {
  description = "ARN of the Redis connection secret"
  type        = string
}

variable "api_target_group_arn" {
  description = "ARN of the API target group"
  type        = string
}

# API Configuration
variable "api_image" {
  description = "Docker image for API service"
  type        = string
}

variable "api_cpu" {
  description = "CPU units for API service"
  type        = number
  default     = 256
}

variable "api_memory" {
  description = "Memory for API service"
  type        = number
  default     = 512
}

variable "api_desired_count" {
  description = "Desired number of API service instances"
  type        = number
  default     = 1
}

# Worker Configuration
variable "worker_image" {
  description = "Docker image for worker service"
  type        = string
}

variable "worker_cpu" {
  description = "CPU units for worker service"
  type        = number
  default     = 256
}

variable "worker_memory" {
  description = "Memory for worker service"
  type        = number
  default     = 512
}

variable "worker_desired_count" {
  description = "Desired number of worker service instances"
  type        = number
  default     = 1
}

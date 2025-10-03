variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "environment" {
  description = "Environment name (production, staging, development)"
  type        = string
}

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "search-sonar"
}

variable "repository_url" {
  description = "GitHub repository URL for the project"
  type        = string
}

variable "domain_name" {
  description = "Custom domain for the application (optional)"
  type        = string
  default     = ""
}

# Database Configuration
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "RDS allocated storage in GB"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "RDS maximum allocated storage in GB"
  type        = number
  default     = 100
}

# Cache Configuration
variable "redis_node_type" {
  description = "ElastiCache Redis node type"
  type        = string
  default     = "cache.t3.micro"
}

variable "redis_num_cache_nodes" {
  description = "Number of cache nodes"
  type        = number
  default     = 1
}

# ECS Configuration
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

variable "api_desired_count" {
  description = "Desired number of API service instances"
  type        = number
  default     = 1
}

variable "worker_desired_count" {
  description = "Desired number of worker service instances"
  type        = number
  default     = 1
}

# Container Images
variable "api_image" {
  description = "Docker image for API service"
  type        = string
  default     = "nginx:latest" # Replace with your actual API image
}

variable "worker_image" {
  description = "Docker image for worker service"
  type        = string
  default     = "nginx:latest" # Replace with your actual worker image
}
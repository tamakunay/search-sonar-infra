# AWS Configuration
aws_region = "ap-southeast-1"

# Project Configuration
project_name = "search-sonar"
environment  = "production"

# Repository Configuration
repository_url = "https://github.com/tamakunay/search-sonar-infra"

# Domain Configuration
domain_name = ""

# Monitoring Configuration
alert_email = "developertaf@outlook.com"

# Database Configuration
db_instance_class        = "db.t3.small"
db_allocated_storage     = 20
db_max_allocated_storage = 100

# Cache Configuration
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 2

# ECS Configuration
api_cpu              = 512
api_memory           = 1024
worker_cpu           = 512
worker_memory        = 1024
api_desired_count    = 2
worker_desired_count = 1

# Container Images
api_image    = "210901781719.dkr.ecr.ap-southeast-1.amazonaws.com/search-sonar-api-production:latest"
worker_image = "210901781719.dkr.ecr.ap-southeast-1.amazonaws.com/search-sonar-worker-production:latest"
# AWS Configuration
aws_region = "ap-southeast-1"

# Project Configuration
project_name = "search-sonar"
environment  = "staging"

# Repository Configuration
repository_url = "https://github.com/tamakunay/search-sonar-infra"

# Domain Configuration
domain_name = ""

# Monitoring Configuration
alert_email = "developertaf@outlook.com"

# Database Configuration
db_instance_class        = "db.t3.micro"
db_allocated_storage     = 20
db_max_allocated_storage = 50

# Cache Configuration
redis_node_type       = "cache.t3.micro"
redis_num_cache_nodes = 1

# ECS Configuration
api_cpu           = 256
api_memory        = 512
worker_cpu        = 256
worker_memory     = 512
api_desired_count = 1
worker_desired_count = 1

# Container Images
api_image    = "210901781719.dkr.ecr.ap-southeast-1.amazonaws.com/search-sonar-api-staging:latest"
worker_image = "210901781719.dkr.ecr.ap-southeast-1.amazonaws.com/search-sonar-worker-staging:latest"
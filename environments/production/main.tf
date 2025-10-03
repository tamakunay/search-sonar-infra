# Local variables
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  name_prefix         = local.name_prefix
  common_tags         = local.common_tags
  availability_zones  = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway  = true
}

# Database Module
module "database" {
  source = "../../modules/database"

  name_prefix               = local.name_prefix
  common_tags               = local.common_tags
  environment               = var.environment
  db_subnet_group_name      = module.networking.db_subnet_group_name
  db_security_group_id      = module.networking.rds_security_group_id
  db_instance_class         = var.db_instance_class
  db_allocated_storage      = var.db_allocated_storage
  db_max_allocated_storage  = var.db_max_allocated_storage
  create_read_replica       = true
}

# Cache Module (Redis)
module "cache" {
  source = "../../modules/cache"

  name_prefix               = local.name_prefix
  common_tags               = local.common_tags
  environment               = var.environment
  cache_subnet_group_name   = module.networking.cache_subnet_group_name
  redis_security_group_id   = module.networking.redis_security_group_id
  redis_node_type           = var.redis_node_type
  redis_num_cache_nodes     = var.redis_num_cache_nodes
}

# Load Balancer Module
module "load_balancer" {
  source = "../../modules/load-balancer"

  name_prefix             = local.name_prefix
  common_tags             = local.common_tags
  environment             = var.environment
  vpc_id                  = module.networking.vpc_id
  public_subnet_ids       = module.networking.public_subnet_ids
  alb_security_group_id   = module.networking.alb_security_group_id
  domain_name             = var.domain_name
}

# ECS Cluster Module
module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name_prefix                   = local.name_prefix
  common_tags                   = local.common_tags
  environment                   = var.environment
  aws_region                    = var.aws_region
  private_subnet_ids            = module.networking.private_subnet_ids
  ecs_security_group_id         = module.networking.ecs_tasks_security_group_id
  db_connection_secret_arn      = module.database.db_connection_secret_arn
  redis_connection_secret_arn   = module.cache.redis_connection_secret_arn
  api_target_group_arn          = module.load_balancer.api_target_group_arn

  # API Configuration
  api_image         = var.api_image
  api_cpu           = var.api_cpu
  api_memory        = var.api_memory
  api_desired_count = var.api_desired_count

  # Worker Configuration
  worker_image         = var.worker_image
  worker_cpu           = var.worker_cpu
  worker_memory        = var.worker_memory
  worker_desired_count = var.worker_desired_count
}

# Frontend Module (Amplify)
module "frontend" {
  source = "../../modules/frontend"

  name_prefix           = local.name_prefix
  common_tags           = local.common_tags
  environment           = var.environment
  repository_url        = var.repository_url
  api_url               = module.load_balancer.api_url
  domain_name           = var.domain_name
  create_develop_branch = true
}

# Monitoring Module
module "monitoring" {
  source = "../../modules/monitoring"

  name_prefix    = local.name_prefix
  common_tags    = local.common_tags
  environment    = var.environment
  aws_region     = var.aws_region
  alert_email    = var.alert_email

  # ALB Variables
  alb_arn_suffix = module.load_balancer.alb_arn

  # ECS Variables
  cluster_name          = module.ecs_cluster.cluster_name
  api_service_name      = module.ecs_cluster.api_service_name
  worker_service_name   = module.ecs_cluster.worker_service_name
  api_log_group_name    = module.ecs_cluster.api_log_group_name
  worker_log_group_name = module.ecs_cluster.worker_log_group_name

  # Database Variables
  db_instance_id = module.database.db_instance_id

  # Redis Variables
  redis_replication_group_id = module.cache.redis_replication_group_id
}
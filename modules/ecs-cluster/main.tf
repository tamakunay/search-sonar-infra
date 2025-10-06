# Application secrets for JWT and other sensitive data
resource "aws_secretsmanager_secret" "app_secrets" {
  name                           = "${var.name_prefix}-app-secrets"
  description                    = "Application secrets for JWT and other sensitive configuration"
  recovery_window_in_days        = 0 # Force immediate deletion to avoid conflicts
  force_overwrite_replica_secret = true

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-app-secrets"
  })
}

resource "aws_secretsmanager_secret_version" "app_secrets" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    jwt_secret         = "your-super-secret-jwt-key-change-this-in-production-${random_password.jwt_secret.result}"
    jwt_refresh_secret = "your-super-secret-refresh-key-change-this-in-production-${random_password.jwt_refresh_secret.result}"
  })
}

resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "random_password" "jwt_refresh_secret" {
  length  = 64
  special = true
}

# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = "${var.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = var.environment == "production" ? "enabled" : "disabled"
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-cluster"
  })
}

# ECS Cluster Capacity Providers
resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

# CloudWatch Log Groups
resource "aws_cloudwatch_log_group" "api" {
  name              = "/ecs/${var.name_prefix}/api"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = var.common_tags
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/ecs/${var.name_prefix}/worker"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = var.common_tags
}

# ECS Task Execution Role
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.name_prefix}-ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Additional policy for Secrets Manager access
resource "aws_iam_role_policy" "ecs_secrets_policy" {
  name = "${var.name_prefix}-ecs-secrets-policy"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.db_connection_secret_arn,
          var.redis_connection_secret_arn,
          aws_secretsmanager_secret.app_secrets.arn
        ]
      }
    ]
  })
}

# ECS Task Role (for application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.name_prefix}-ecs-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags

  lifecycle {
    prevent_destroy = true
  }
}

# Task role policy for application-specific permissions
resource "aws_iam_role_policy" "ecs_task_policy" {
  name = "${var.name_prefix}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = [
          var.db_connection_secret_arn,
          var.redis_connection_secret_arn,
          aws_secretsmanager_secret.app_secrets.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "${aws_cloudwatch_log_group.api.arn}:*",
          "${aws_cloudwatch_log_group.worker.arn}:*"
        ]
      }
    ]
  })
}

# API Task Definition
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.name_prefix}-api"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.api_cpu
  memory                   = var.api_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    # Main API container
    {
      name  = "api"
      image = var.api_image

      portMappings = [
        {
          containerPort = 4000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "PORT"
          value = "4000"
        },
        {
          name  = "BASE_PATH"
          value = "api"
        },
        {
          name  = "LOG_LEVEL"
          value = var.environment == "production" ? "info" : "debug"
        },
        {
          name  = "SALT_ROUNDS"
          value = "10"
        },
        {
          name  = "JWT_EXPIRATION"
          value = "15m"
        },
        {
          name  = "JWT_REFRESH_EXPIRATION"
          value = "7d"
        },
        {
          name  = "EMAIL_ENABLED"
          value = "false"
        },
        {
          name  = "EMAIL_HOST"
          value = ""
        },
        {
          name  = "EMAIL_PORT"
          value = "587"
        },
        {
          name  = "EMAIL_SECURE"
          value = "false"
        },
        {
          name  = "EMAIL_USER"
          value = ""
        },
        {
          name  = "EMAIL_PASS"
          value = ""
        },
        {
          name  = "EMAIL_FROM"
          value = ""
        },
        {
          name  = "EMAIL_FROM_NAME"
          value = ""
        },
        {
          name  = "CSV_MAX_FILE_SIZE_MB"
          value = "10"
        },
        {
          name  = "CSV_MAX_KEYWORDS"
          value = "100"
        },
        {
          name  = "APP_URL"
          value = "http://${var.load_balancer_dns_name}"
        },
        {
          name  = "POSTGRES_SSL"
          value = "true"
        },
        {
          name  = "PGSSLMODE"
          value = "require"
        }
      ]

      secrets = [
        {
          name      = "POSTGRES_HOST"
          valueFrom = "${var.db_connection_secret_arn}:host::"
        },
        {
          name      = "POSTGRES_PORT"
          valueFrom = "${var.db_connection_secret_arn}:port::"
        },
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.db_connection_secret_arn}:username::"
        },
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${var.db_connection_secret_arn}:password::"
        },
        {
          name      = "POSTGRES_DB"
          valueFrom = "${var.db_connection_secret_arn}:database::"
        },
        {
          name      = "REDIS_HOST"
          valueFrom = "${var.redis_connection_secret_arn}:host::"
        },
        {
          name      = "REDIS_PORT"
          valueFrom = "${var.redis_connection_secret_arn}:port::"
        },
        {
          name      = "REDIS_PASSWORD"
          valueFrom = "${var.redis_connection_secret_arn}:auth_token::"
        },
        {
          name      = "JWT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:jwt_secret::"
        },
        {
          name      = "JWT_REFRESH_SECRET"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:jwt_refresh_secret::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.api.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      healthCheck = {
        command     = ["CMD-SHELL", "curl -f http://localhost:4000/api/v1/health || exit 1"]
        interval    = 30
        timeout     = 5
        retries     = 3
        startPeriod = 90 # Increased to allow time for migrations
      }

      essential = true
    }
  ])

  tags = var.common_tags
}

# Worker Task Definition
resource "aws_ecs_task_definition" "worker" {
  family                   = "${var.name_prefix}-worker"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.worker_cpu
  memory                   = var.worker_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name  = "worker"
      image = var.worker_image

      environment = [
        {
          name  = "NODE_ENV"
          value = var.environment
        },
        {
          name  = "LOG_LEVEL"
          value = var.environment == "production" ? "info" : "debug"
        },
        {
          name  = "POSTGRES_SSL"
          value = "true"
        },
        {
          name  = "PGSSLMODE"
          value = "require"
        },
        {
          name  = "EMAIL_ENABLED"
          value = "false"
        },
        {
          name  = "EMAIL_HOST"
          value = ""
        },
        {
          name  = "EMAIL_PORT"
          value = "587"
        },
        {
          name  = "EMAIL_SECURE"
          value = "false"
        },
        {
          name  = "EMAIL_USER"
          value = ""
        },
        {
          name  = "EMAIL_PASS"
          value = ""
        },
        {
          name  = "EMAIL_FROM"
          value = ""
        },
        {
          name  = "EMAIL_FROM_NAME"
          value = ""
        },
        {
          name  = "PORT"
          value = "3002"
        },
        {
          name  = "WORKER_CONCURRENCY"
          value = "1"
        },
        {
          name  = "MAX_CONCURRENT_JOBS"
          value = "1"
        },
        {
          name  = "QUEUE_NAME"
          value = "keyword-processing"
        },
        {
          name  = "JOB_ATTEMPTS"
          value = "3"
        },
        {
          name  = "JOB_BACKOFF_DELAY"
          value = "5000"
        },
        {
          name  = "USER_AGENTS"
          value = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
        },
        {
          name  = "REQUEST_DELAY_MIN"
          value = "2000"
        },
        {
          name  = "REQUEST_DELAY_MAX"
          value = "5000"
        },
        {
          name  = "PAGE_TIMEOUT"
          value = "30000"
        },
        {
          name  = "SCRAPING_TIMEOUT"
          value = "30000"
        },
        {
          name  = "PUPPETEER_HEADLESS"
          value = "true"
        },
        {
          name  = "HEADLESS"
          value = "true"
        },
        {
          name  = "PUPPETEER_EXECUTABLE_PATH"
          value = ""
        },
        {
          name  = "PUPPETEER_ARGS"
          value = "--no-sandbox,--disable-setuid-sandbox,--disable-dev-shm-usage"
        },
        {
          name  = "WEBSOCKET_URL"
          value = "ws://${var.load_balancer_dns_name}:3001"
        },
        {
          name  = "WEBSOCKET_NAMESPACE"
          value = "/keywords-progress"
        },
        {
          name  = "LOG_FORMAT"
          value = "json"
        },
        {
          name  = "MAX_RETRIES"
          value = "3"
        },
        {
          name  = "RETRY_DELAY"
          value = "5000"
        },
        {
          name  = "CIRCUIT_BREAKER_THRESHOLD"
          value = "5"
        },
        {
          name  = "MEMORY_LIMIT"
          value = "512"
        },
        {
          name  = "CPU_LIMIT"
          value = "1"
        }
      ]

      # Note: DATABASE_URL and REDIS_URL are constructed from individual components
      # in the application code since ECS doesn't support dynamic secret interpolation
      # in environment variables. The worker should construct these URLs like:
      # DATABASE_URL = `postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT}/${POSTGRES_DB}`
      # REDIS_URL = `redis://${REDIS_PASSWORD ? ':' + REDIS_PASSWORD + '@' : ''}${REDIS_HOST}:${REDIS_PORT}`

      secrets = [
        {
          name      = "POSTGRES_HOST"
          valueFrom = "${var.db_connection_secret_arn}:host::"
        },
        {
          name      = "POSTGRES_PORT"
          valueFrom = "${var.db_connection_secret_arn}:port::"
        },
        {
          name      = "POSTGRES_USER"
          valueFrom = "${var.db_connection_secret_arn}:username::"
        },
        {
          name      = "POSTGRES_PASSWORD"
          valueFrom = "${var.db_connection_secret_arn}:password::"
        },
        {
          name      = "POSTGRES_DB"
          valueFrom = "${var.db_connection_secret_arn}:database::"
        },
        {
          name      = "REDIS_HOST"
          valueFrom = "${var.redis_connection_secret_arn}:host::"
        },
        {
          name      = "REDIS_PORT"
          valueFrom = "${var.redis_connection_secret_arn}:port::"
        },
        {
          name      = "REDIS_PASSWORD"
          valueFrom = "${var.redis_connection_secret_arn}:auth_token::"
        },
        {
          name      = "JWT_SECRET"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:jwt_secret::"
        },
        {
          name      = "JWT_REFRESH_SECRET"
          valueFrom = "${aws_secretsmanager_secret.app_secrets.arn}:jwt_refresh_secret::"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.worker.name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }

      essential = true
    }
  ])

  tags = var.common_tags
}

# API ECS Service
resource "aws_ecs_service" "api" {
  name            = "${var.name_prefix}-api"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = var.api_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = "api"
    container_port   = 4000
  }

  depends_on = [var.api_target_group_arn]

  tags = var.common_tags
}

# Worker ECS Service
resource "aws_ecs_service" "worker" {
  name            = "${var.name_prefix}-worker"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.worker.arn
  desired_count   = var.worker_desired_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [var.ecs_security_group_id]
    subnets          = var.private_subnet_ids
    assign_public_ip = false
  }

  tags = var.common_tags
}

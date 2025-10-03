# Amplify App
resource "aws_amplify_app" "main" {
  name       = "${var.name_prefix}-web"
  repository = var.repository_url

  # Build settings
  build_spec = var.build_spec != "" ? var.build_spec : file("${path.module}/amplify.yml")

  # Environment variables
  environment_variables = merge(
    {
      AMPLIFY_MONOREPO_APP_ROOT = "apps/web"
      NODE_ENV                  = var.environment
      VITE_APP_NAME            = "Search Sonar"
    },
    var.environment_variables
  )

  # Platform
  platform = "WEB_COMPUTE"

  # IAM role for Amplify
  iam_service_role_arn = aws_iam_role.amplify.arn

  # Custom rules for SPA routing
  custom_rule {
    source = "/<*>"
    status = "404-200"
    target = "/index.html"
  }

  # API proxy rules
  custom_rule {
    source = "/api/<*>"
    status = "200"
    target = "${var.api_url}/<*>"
  }

  tags = var.common_tags
}

# IAM role for Amplify
resource "aws_iam_role" "amplify" {
  name = "${var.name_prefix}-amplify-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "amplify.amazonaws.com"
        }
      }
    ]
  })

  tags = var.common_tags
}

resource "aws_iam_role_policy_attachment" "amplify_backend_deploy" {
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess-Amplify"
  role       = aws_iam_role.amplify.name
}

# Main branch
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.main.id
  branch_name = var.main_branch_name

  # Environment variables specific to main branch
  environment_variables = merge(
    {
      VITE_API_URL = var.api_url
    },
    var.main_branch_environment_variables
  )

  # Enable auto build
  enable_auto_build = true

  tags = var.common_tags
}

# Development branch (optional)
resource "aws_amplify_branch" "develop" {
  count = var.create_develop_branch ? 1 : 0

  app_id      = aws_amplify_app.main.id
  branch_name = "develop"

  # Environment variables specific to develop branch
  environment_variables = merge(
    {
      VITE_API_URL  = var.dev_api_url != "" ? var.dev_api_url : var.api_url
      VITE_APP_NAME = "Search Sonar (Dev)"
    },
    var.develop_branch_environment_variables
  )

  # Enable auto build
  enable_auto_build = true

  tags = var.common_tags
}

# Custom domain (if provided)
resource "aws_amplify_domain_association" "main" {
  count = var.domain_name != "" ? 1 : 0

  app_id      = aws_amplify_app.main.id
  domain_name = var.domain_name

  # Subdomain configuration
  sub_domain {
    branch_name = aws_amplify_branch.main.branch_name
    prefix      = var.subdomain_prefix
  }

  # Development subdomain (if develop branch exists)
  dynamic "sub_domain" {
    for_each = var.create_develop_branch ? [1] : []
    content {
      branch_name = aws_amplify_branch.develop[0].branch_name
      prefix      = "dev"
    }
  }

  # Wait for certificate validation
  depends_on = [aws_amplify_branch.main]
}

# Webhook for GitHub integration
resource "aws_amplify_webhook" "main" {
  app_id      = aws_amplify_app.main.id
  branch_name = aws_amplify_branch.main.branch_name
  description = "Webhook for ${var.main_branch_name} branch"
}

resource "aws_amplify_webhook" "develop" {
  count = var.create_develop_branch ? 1 : 0

  app_id      = aws_amplify_app.main.id
  branch_name = aws_amplify_branch.develop[0].branch_name
  description = "Webhook for develop branch"
}

# CloudWatch Log Group for Amplify
resource "aws_cloudwatch_log_group" "amplify" {
  name              = "/aws/amplify/${aws_amplify_app.main.name}"
  retention_in_days = var.environment == "production" ? 30 : 7

  tags = var.common_tags
}

# CloudWatch Alarms for Amplify (production only)
resource "aws_cloudwatch_metric_alarm" "amplify_build_failures" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "${var.name_prefix}-amplify-build-failures"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "BuildFailures"
  namespace           = "AWS/Amplify"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "This metric monitors Amplify build failures"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    App = aws_amplify_app.main.name
  }

  tags = var.common_tags
}

# Output the default build spec if none provided
locals {
  default_build_spec = <<-EOT
version: 1
applications:
  - appRoot: apps/web
    frontend:
      phases:
        preBuild:
          commands:
            - npm ci
        build:
          commands:
            - npm run build --workspace=search-sonar-web
      artifacts:
        baseDirectory: apps/web/dist
        files:
          - '**/*'
      cache:
        paths:
          - node_modules/**/*
          - apps/web/node_modules/**/*
EOT
}

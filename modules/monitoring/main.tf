# SNS Topic for Alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = var.common_tags
}

# SNS Topic Subscription (Email)
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name_prefix}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Application Load Balancer Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ECS", "CPUUtilization", "ServiceName", var.api_service_name, "ClusterName", var.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."],
            [".", "CPUUtilization", "ServiceName", var.worker_service_name, "ClusterName", var.cluster_name],
            [".", "MemoryUtilization", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ECS Service Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id],
            [".", "DatabaseConnections", ".", "."],
            [".", "FreeableMemory", ".", "."],
            [".", "FreeStorageSpace", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "RDS Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 6
        y      = 12
        width  = 6
        height = 6

        properties = {
          metrics = [
            ["AWS/ElastiCache", "CPUUtilization", "CacheClusterId", "${var.redis_replication_group_id}-001"],
            [".", "DatabaseMemoryUsagePercentage", ".", "."],
            [".", "CurrConnections", ".", "."],
            [".", "NetworkBytesIn", ".", "."],
            [".", "NetworkBytesOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ElastiCache Redis Metrics"
          period  = 300
        }
      }
    ]
  })
}

# CloudWatch Log Insights Queries
resource "aws_cloudwatch_query_definition" "api_errors" {
  name = "${var.name_prefix}-api-errors"

  log_group_names = [
    var.api_log_group_name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "worker_errors" {
  name = "${var.name_prefix}-worker-errors"

  log_group_names = [
    var.worker_log_group_name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 100
EOF
}

resource "aws_cloudwatch_query_definition" "api_performance" {
  name = "${var.name_prefix}-api-performance"

  log_group_names = [
    var.api_log_group_name
  ]

  query_string = <<EOF
fields @timestamp, @message
| filter @message like /response time/
| stats avg(@duration) by bin(5m)
EOF
}

# Composite Alarms for Application Health
resource "aws_cloudwatch_composite_alarm" "application_health" {
  count = var.environment == "production" ? 1 : 0

  alarm_name        = "${var.name_prefix}-application-health"
  alarm_description = "Composite alarm for overall application health"

  alarm_rule = join(" OR ", compact([
    var.alb_target_response_time_alarm_name != "" ? "ALARM(${var.alb_target_response_time_alarm_name})" : "",
    var.alb_healthy_host_count_alarm_name != "" ? "ALARM(${var.alb_healthy_host_count_alarm_name})" : "",
    var.alb_http_5xx_count_alarm_name != "" ? "ALARM(${var.alb_http_5xx_count_alarm_name})" : "",
    var.redis_cpu_alarm_name != "" ? "ALARM(${var.redis_cpu_alarm_name})" : "",
    var.redis_memory_alarm_name != "" ? "ALARM(${var.redis_memory_alarm_name})" : ""
  ]))

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.common_tags
}

# Custom Metrics for Business Logic
resource "aws_cloudwatch_log_metric_filter" "api_requests" {
  name           = "${var.name_prefix}-api-requests"
  log_group_name = var.api_log_group_name
  pattern        = "[timestamp, request_id, method, path, status_code, response_time]"

  metric_transformation {
    name      = "APIRequests"
    namespace = "${var.name_prefix}/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "worker_jobs_processed" {
  name           = "${var.name_prefix}-worker-jobs-processed"
  log_group_name = var.worker_log_group_name
  pattern        = "[timestamp, level=\"INFO\", message=\"Job completed\", job_id, duration]"

  metric_transformation {
    name      = "WorkerJobsProcessed"
    namespace = "${var.name_prefix}/Application"
    value     = "1"
  }
}

resource "aws_cloudwatch_log_metric_filter" "worker_jobs_failed" {
  name           = "${var.name_prefix}-worker-jobs-failed"
  log_group_name = var.worker_log_group_name
  pattern        = "[timestamp, level=\"ERROR\", message=\"Job failed\", job_id, error]"

  metric_transformation {
    name      = "WorkerJobsFailed"
    namespace = "${var.name_prefix}/Application"
    value     = "1"
  }
}

# Alarms for Custom Metrics
resource "aws_cloudwatch_metric_alarm" "worker_job_failure_rate" {
  count = var.environment == "production" ? 1 : 0

  alarm_name          = "${var.name_prefix}-worker-job-failure-rate"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  threshold           = "5"
  alarm_description   = "This metric monitors worker job failure rate"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  metric_query {
    id          = "e1"
    expression  = "m2/m1*100"
    label       = "Job Failure Rate"
    return_data = "true"
  }

  metric_query {
    id = "m1"
    metric {
      metric_name = "WorkerJobsProcessed"
      namespace   = "${var.name_prefix}/Application"
      period      = "300"
      stat        = "Sum"
    }
  }

  metric_query {
    id = "m2"
    metric {
      metric_name = "WorkerJobsFailed"
      namespace   = "${var.name_prefix}/Application"
      period      = "300"
      stat        = "Sum"
    }
  }

  tags = var.common_tags
}

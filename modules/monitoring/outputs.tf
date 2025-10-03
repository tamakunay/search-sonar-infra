output "sns_topic_arn" {
  description = "ARN of the SNS topic for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "dashboard_url" {
  description = "URL of the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

output "log_insights_api_errors_query" {
  description = "CloudWatch Log Insights query for API errors"
  value       = aws_cloudwatch_query_definition.api_errors.query_string
}

output "log_insights_worker_errors_query" {
  description = "CloudWatch Log Insights query for worker errors"
  value       = aws_cloudwatch_query_definition.worker_errors.query_string
}

output "log_insights_api_performance_query" {
  description = "CloudWatch Log Insights query for API performance"
  value       = aws_cloudwatch_query_definition.api_performance.query_string
}

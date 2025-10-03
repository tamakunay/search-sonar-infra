output "app_id" {
  description = "Amplify App ID"
  value       = aws_amplify_app.main.id
}

output "app_arn" {
  description = "Amplify App ARN"
  value       = aws_amplify_app.main.arn
}

output "default_domain" {
  description = "Default Amplify domain"
  value       = aws_amplify_app.main.default_domain
}

output "main_branch_url" {
  description = "URL of the main branch deployment"
  value       = "https://${aws_amplify_branch.main.branch_name}.${aws_amplify_app.main.default_domain}"
}

output "develop_branch_url" {
  description = "URL of the develop branch deployment"
  value       = var.create_develop_branch ? "https://${aws_amplify_branch.develop[0].branch_name}.${aws_amplify_app.main.default_domain}" : null
}

output "custom_domain_url" {
  description = "Custom domain URL"
  value       = var.domain_name != "" ? "https://${var.subdomain_prefix != "" ? "${var.subdomain_prefix}." : ""}${var.domain_name}" : null
}

output "main_webhook_url" {
  description = "Webhook URL for main branch"
  value       = aws_amplify_webhook.main.url
  sensitive   = true
}

output "develop_webhook_url" {
  description = "Webhook URL for develop branch"
  value       = var.create_develop_branch ? aws_amplify_webhook.develop[0].url : null
  sensitive   = true
}

output "domain_association_certificate_verification_dns_record" {
  description = "DNS record for domain verification"
  value       = var.domain_name != "" ? aws_amplify_domain_association.main[0].certificate_verification_dns_record : null
}

output "build_spec" {
  description = "Build specification used"
  value       = var.build_spec != "" ? var.build_spec : local.default_build_spec
}

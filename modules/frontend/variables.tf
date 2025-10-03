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

variable "repository_url" {
  description = "GitHub repository URL"
  type        = string
}

variable "api_url" {
  description = "API URL for the frontend to connect to"
  type        = string
}

variable "dev_api_url" {
  description = "Development API URL (optional, defaults to api_url)"
  type        = string
  default     = ""
}

variable "domain_name" {
  description = "Custom domain for the frontend"
  type        = string
  default     = ""
}

variable "subdomain_prefix" {
  description = "Subdomain prefix (empty for root domain)"
  type        = string
  default     = ""
}

variable "main_branch_name" {
  description = "Name of the main branch"
  type        = string
  default     = "main"
}

variable "create_develop_branch" {
  description = "Create a develop branch deployment"
  type        = bool
  default     = false
}

variable "build_spec" {
  description = "Custom build specification (amplify.yml content)"
  type        = string
  default     = ""
}

variable "environment_variables" {
  description = "Environment variables for all branches"
  type        = map(string)
  default     = {}
}

variable "main_branch_environment_variables" {
  description = "Environment variables specific to main branch"
  type        = map(string)
  default     = {}
}

variable "develop_branch_environment_variables" {
  description = "Environment variables specific to develop branch"
  type        = map(string)
  default     = {}
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for CloudWatch alarms"
  type        = string
  default     = ""
}

terraform {
  backend "s3" {
    bucket         = "search-sonar-terraform-state"
    key            = "staging/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "search-sonar-terraform-locks"
  }
}
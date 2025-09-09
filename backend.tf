
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket-name" # CHANGE THIS
    key            = "infrastructure-upgrade/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "your-terraform-state-lock-table-name" # CHANGE THIS
    encrypt        = true
  }
}

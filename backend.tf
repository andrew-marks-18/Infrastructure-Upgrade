
terraform {
  backend "s3" {
    bucket         = "upgrade-terraform-state-us-east-2"
    key            = "infrastructure-upgrade/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "upgrade-terraform-state-lock"
    encrypt        = true
  }
}

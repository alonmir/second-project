terraform {
  backend "s3" {
    bucket         = "alon-tfstate1202"
    key            = "asterra/dev/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "terraform-locks-new"
    encrypt        = true
  }
}


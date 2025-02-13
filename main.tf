terraform {
#   backend "s3" {
#     bucket = "${company_prefix}-tfstate-${local.account_id}"
#     key    = "backend.tfstate"
#     region = "eu-west-2"
#   }

  # TODO figure out how to get dynamic bucket name based on account id ^

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.85"
    }
  }
}


provider "aws" {
  region = "eu-west-2"

  default_tags {
    tags = {
      created_via = "${var.company_prefix}-terraform"
      project = "sandbox-system"
    }
  }
}

data "aws_caller_identity" "current" {}
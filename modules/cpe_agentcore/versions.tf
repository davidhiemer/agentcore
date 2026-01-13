terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.40.0, < 6.0.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = ">= 1.0.0, < 2.0.0"
    }
  }
}


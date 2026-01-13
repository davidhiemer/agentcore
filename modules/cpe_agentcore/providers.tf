provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }

  # Explicit retry configuration for banking reliability requirements
  retry_mode  = "adaptive"
  max_retries = 5
}

provider "awscc" {
  region = var.aws_region
}


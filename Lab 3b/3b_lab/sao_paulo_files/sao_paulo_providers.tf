terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

# Default provider — São Paulo (stateless compute)
provider "aws" {
  region = var.aws_region # sa-east-1
}

# us-east-1 alias required for CloudFront WAF and ACM certs
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

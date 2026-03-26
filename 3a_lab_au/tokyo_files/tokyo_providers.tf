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

# Default provider — Tokyo (data authority, APPI-compliant PHI storage)
provider "aws" {
  region = var.aws_region # ap-northeast-1
}

# us-east-1 alias required for CloudFront WAF and ACM certs (CloudFront requires us-east-1)
provider "aws" {
  alias  = "east"
  region = "us-east-1"
}

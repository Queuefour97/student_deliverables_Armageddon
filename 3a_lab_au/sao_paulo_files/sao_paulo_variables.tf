variable "aws_region" {
  description = "AWS Region for liberdade (Sao Paulo - stateless compute)."
  type        = string
  default     = "sa-east-1" # FIX: was us-east-1
}

variable "project_name" {
  description = "Prefix for naming. Must start with 'liberdade-'."
  type        = string
  default     = "liberdade-final"
}

variable "vpc_cidr" {
  description = "VPC CIDR for Sao Paulo. Must NOT overlap with Tokyo (10.100.0.0/16)."
  type        = string
  default     = "10.200.0.0/16" # FIX: was 10.108.0.0/16 - clashed with Tokyo
}

variable "my_ip" {
  description = "Your public IP for SSH access (CIDR notation)."
  type        = string
  default     = "99.184.18.128/32"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for Sao Paulo."
  type        = list(string)
  default     = ["10.200.1.0/24", "10.200.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for Sao Paulo."
  type        = list(string)
  default     = ["10.200.101.0/24", "10.200.102.0/24"]
}

variable "azs" {
  description = "Availability Zones in sa-east-1."
  type        = list(string)
  default     = ["sa-east-1a", "sa-east-1c"] # FIX: was us-east-1a/b
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 in sa-east-1. Amazon Linux 2023."
  type        = string
  default     = "ami-0c820c196a818d66a" # Amazon Linux 2023 sa-east-1
}

variable "ec2_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "sns_email_endpoint" {
  type    = string
  default = "jorune.simpkins@gmail.com"
}

variable "domain_name" {
  type    = string
  default = "firstpointand.click"
}

variable "app_subdomain" {
  type    = string
  default = "app"
}

variable "certificate_validation_method" {
  type    = string
  default = "DNS"
}

variable "enable_waf" {
  type    = bool
  default = true
}

variable "alb_5xx_threshold" {
  type    = number
  default = 10
}

variable "alb_5xx_period_seconds" {
  type    = number
  default = 300
}

variable "alb_5xx_evaluation_periods" {
  type    = number
  default = 1
}

variable "manage_route53_in_terraform" {
  type    = bool
  default = false
}

variable "route53_hosted_zone_id" {
  type    = string
  default = "Z0577510JJCMGIYZ7086"
}

variable "enable_alb_access_logs" {
  type    = bool
  default = true
}

variable "alb_access_logs_prefix" {
  type    = string
  default = "alb-access-logs"
}

variable "waf_log_destination" {
  type    = string
  default = "cloudwatch"
}

variable "waf_log_retention_days" {
  type    = number
  default = 14
}

variable "enable_waf_sampled_requests_only" {
  type    = bool
  default = false
}

# ── Lab 3A: Tokyo values consumed from remote state ──────────────────────────

variable "tokyo_vpc_cidr" {
  description = "Tokyo VPC CIDR - used to build TGW routes in Sao Paulo private subnets."
  type        = string
  default     = "10.100.0.0/16"
}

variable "tokyo_tgw_peering_attachment_id" {
  description = "TGW peering attachment ID from Tokyo (requester side). Sao Paulo accepts this."
  type        = string
  default     = "" # Students populate from Tokyo outputs after first Tokyo apply
}

variable "tokyo_rds_endpoint" {
  description = "Tokyo RDS endpoint - stored in SSM Parameter Store for app consumption."
  type        = string
  default     = "" # Students populate from Tokyo outputs
}

variable "tokyo_rds_port" {
  description = "Tokyo RDS port."
  type        = number
  default     = 3306
}

# -- CloudFront values from Tokyo (separate state -- pass via -var after Tokyo apply) --

variable "tokyo_cloudfront_domain_name" {
  description = "CloudFront distribution domain name from Tokyo outputs. Pass after Tokyo apply."
  type        = string
  default     = ""
}

variable "tokyo_cloudfront_hosted_zone_id" {
  description = "CloudFront hosted zone ID from Tokyo outputs. Pass after Tokyo apply."
  type        = string
  default     = "Z2FDTNDATAQYW2" # CloudFront hosted zone ID is always this value globally
}

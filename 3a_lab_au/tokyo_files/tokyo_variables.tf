variable "aws_region" {
  description = "AWS Region for shinjuku (Tokyo - data authority)."
  type        = string
  default     = "ap-northeast-1" # FIX: was incorrectly set to us-east-1
}

variable "project_name" {
  description = "Prefix for naming. Must start with 'shinjuku-'."
  type        = string
  default     = "shinjuku-final"
}

variable "vpc_cidr" {
  description = "VPC CIDR for Tokyo. Must NOT overlap with Sao Paulo (10.200.0.0/16)."
  type        = string
  default     = "10.100.0.0/16" # FIX: was 10.108.0.0/16 - clashed with Sao Paulo
}

variable "my_ip" {
  description = "Your public IP for SSH access (CIDR notation)."
  type        = string
  default     = "99.184.18.128/32"
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs for Tokyo."
  type        = list(string)
  default     = ["10.100.1.0/24", "10.100.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs for Tokyo."
  type        = list(string)
  default     = ["10.100.101.0/24", "10.100.102.0/24"]
}

variable "azs" {
  description = "Availability Zones in ap-northeast-1."
  type        = list(string)
  default     = ["ap-northeast-1a", "ap-northeast-1c"] # FIX: was us-east-1a/b
}

variable "ec2_ami_id" {
  description = "AMI ID for EC2 in ap-northeast-1. al2023-ami-2023 for Tokyo."
  type        = string
  default     = "ami-088b486f20fab3f0e" # Amazon Linux 2023 ap-northeast-1 (al2023-ami-2023.10.20260302.1)
}

variable "ec2_instance_type" {
  description = "EC2 instance size."
  type        = string
  default     = "t3.micro"
}

variable "db_engine" {
  description = "RDS engine."
  type        = string
  default     = "mysql"
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.micro"
}

variable "db_name" {
  description = "Initial database name."
  type        = string
  default     = "labdb"
}

variable "db_username" {
  description = "DB master username."
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "DB master password (lab only - use Secrets Manager in production)."
  type        = string
  sensitive   = true
  default     = "shinjuku-lab3!"
}

variable "sns_email_endpoint" {
  description = "Email for SNS alarm subscription."
  type        = string
  default     = "jorune.simpkins@gmail.com"
}

variable "domain_name" {
  description = "Base domain (e.g., firstpointand.click)."
  type        = string
  default     = "firstpointand.click"
}

variable "app_subdomain" {
  description = "Subdomain prefix."
  type        = string
  default     = "app"
}

variable "certificate_validation_method" {
  description = "ACM validation method."
  type        = string
  default     = "DNS"
}

variable "enable_waf" {
  description = "Toggle WAF creation."
  type        = bool
  default     = true
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
  description = "cloudwatch | s3 | firehose"
  type        = string
  default     = "cloudwatch"
}

variable "waf_log_retention_days" {
  type    = number
  default = 14
}

variable "enable_waf_sampled_requests_only" {
  type    = bool
  default = false
}

# ── Lab 3A: Sao Paulo CIDR (needed for RDS SG rule) ──────────────────────────
variable "saopaulo_vpc_cidr" {
  description = "Sao Paulo VPC CIDR - added to Tokyo RDS SG so cross-region EC2 can reach MySQL."
  type        = string
  default     = "10.200.0.0/16"
}

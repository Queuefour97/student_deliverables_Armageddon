############################################
# tokyo_outputs.tf
#
# Lab 3A additions at the bottom expose TGW ID,
# VPC CIDR, and RDS endpoint so São Paulo can
# consume them via remote state.
#
# Resources like shinjuku_alb_sg01, shinjuku_alb01,
# shinjuku_tg01, shinjuku_cf01, random_password, and
# the S3 log buckets are declared in bonus_a.tf and
# bonus_b.tf — those files must be present for this
# outputs file to plan successfully.
############################################

output "shinjuku_vpc_id" {
  value = aws_vpc.shinjuku_vpc01.id
}

output "shinjuku_public_subnet_ids" {
  value = aws_subnet.shinjuku_public_subnets[*].id
}

output "shinjuku_private_subnet_ids" {
  value = aws_subnet.shinjuku_private_subnets[*].id
}

output "shinjuku_ec2_instance_id" {
  value = aws_instance.shinjuku_ec201.id
}

output "shinjuku_rds_endpoint" {
  description = "Tokyo RDS endpoint — consumed by São Paulo SSM Parameter Store and app config."
  value       = aws_db_instance.shinjuku_rds01.address
}

output "shinjuku_rds_port" {
  value = aws_db_instance.shinjuku_rds01.port
}

output "shinjuku_sns_topic_arn" {
  value = aws_sns_topic.shinjuku_sns_topic01.arn
}

output "shinjuku_log_group_name" {
  value = aws_cloudwatch_log_group.shinjuku_log_group01.name
}

output "shinjuku_app_url_https" {
  value = "https://${var.app_subdomain}.${var.domain_name}"
}

output "shinjuku_apex_url_https" {
  value = "https://${var.domain_name}"
}

# These outputs reference resources in bonus_a.tf / bonus_b.tf.
# They are valid as long as those files exist in the tokyo/ folder.

output "shinjuku_alb_logs_bucket_name" {
  description = "ALB access logs S3 bucket name (bonus_a.tf). Null if enable_alb_access_logs = false."
  value       = var.enable_alb_access_logs ? aws_s3_bucket.shinjuku_alb_logs_bucket01[0].bucket : null
}

output "shinjuku_waf_log_destination" {
  value = var.waf_log_destination
}

output "shinjuku_waf_logs_s3_bucket" {
  description = "WAF S3 log bucket (bonus_a.tf). Null if waf_log_destination != 's3'."
  value       = var.waf_log_destination == "s3" ? aws_s3_bucket.shinjuku_waf_logs_bucket01[0].bucket : null
}

output "alb_sg_id" {
  description = "ALB security group ID (bonus_b.tf)."
  value       = aws_security_group.shinjuku_alb_sg01.id
}

output "alb_dns_name" {
  description = "ALB DNS name (bonus_b.tf)."
  value       = aws_lb.shinjuku_alb01.dns_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID (bonus_b.tf)."
  value       = aws_cloudfront_distribution.shinjuku_cf01.id
}

output "target_group_arn" {
  description = "ALB target group ARN (bonus_b.tf)."
  value       = aws_lb_target_group.shinjuku_tg01.arn
}

output "shinjuku_origin_header_value" {
  description = "Random secret passed as X-Origin-Verify header (bonus_b.tf)."
  value       = random_password.shinjuku_origin_header_value01.result
  sensitive   = true
}

# ── Lab 3A Outputs (consumed by São Paulo remote state) ────────────────────────

output "tokyo_vpc_cidr" {
  description = "Tokyo VPC CIDR — São Paulo uses this to build TGW routes."
  value       = var.vpc_cidr
}

output "tokyo_tgw_id" {
  description = "Tokyo Transit Gateway ID — São Paulo peering attachment targets this."
  value       = aws_ec2_transit_gateway.shinjuku_tgw01.id
}

output "tokyo_tgw_peering_attachment_id" {
  description = "The peering attachment ID (requester side) — São Paulo accepts this."
  value       = aws_ec2_transit_gateway_peering_attachment.shinjuku_tgw_peering01.id
}

output "shinjuku_route53_zone_id" {
  description = "Route53 hosted zone ID."
  value       = local.shinjuku_zone_id
}

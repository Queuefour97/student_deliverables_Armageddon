############################################
# São Paulo Outputs
############################################

output "liberdale_vpc_id" {
  value = aws_vpc.liberdale_vpc01.id
}

output "liberdale_public_subnet_ids" {
  value = aws_subnet.liberdale_public_subnets[*].id
}

output "liberdale_private_subnet_ids" {
  value = aws_subnet.liberdale_private_subnets[*].id
}

output "liberdale_ec2_instance_id" {
  value = aws_instance.liberdale_ec201.id
}

output "liberdale_sns_topic_arn" {
  value = aws_sns_topic.liberdale_sns_topic01.arn
}

output "liberdale_log_group_name" {
  value = aws_cloudwatch_log_group.liberdale_log_group01.name
}

output "liberdale_app_url_https" {
  value = "https://${var.app_subdomain}.${var.domain_name}"
}

output "liberdale_apex_url_https" {
  value = "https://${var.domain_name}"
}

output "liberdale_alb_logs_bucket_name" {
  value = var.enable_alb_access_logs ? aws_s3_bucket.liberdale_alb_logs_bucket01[0].bucket : null
}

output "liberdale_waf_log_destination" {
  value = var.waf_log_destination
}

output "liberdale_waf_logs_s3_bucket" {
  value = var.waf_log_destination == "s3" ? aws_s3_bucket.liberdale_waf_logs_bucket01[0].bucket : null
}

output "alb_sg_id" {
  value = aws_security_group.liberdale_alb_sg01.id
}

output "alb_dns_name" {
  value = aws_lb.liberdale_alb01.dns_name
}

# cloudfront_distribution_id — REMOVED: São Paulo does not own a CF distribution
# Tokyo's shinjuku_cf01 is the single global distribution. See tokyo/tokyo_outputs.tf.
# 

output "target_group_arn" {
  value = aws_lb_target_group.liberdale_tg01.arn
}

output "liberdale_origin_header_value" {
  value     = random_password.liberdale_origin_header_value01.result
  sensitive = true
}

# ── Lab 3A Outputs ────────────────────────────────────────────────────────────

output "saopaulo_vpc_cidr" {
  description = "São Paulo VPC CIDR — Tokyo needs this to configure the return route."
  value       = var.vpc_cidr
}

output "saopaulo_tgw_id" {
  description = "São Paulo TGW ID — provided to Tokyo so it can create the peering request."
  value       = aws_ec2_transit_gateway.liberdale_tgw01.id
}

output "tokyo_rds_endpoint_in_use" {
  description = "Confirms which Tokyo RDS endpoint this São Paulo deploy is targeting."
  value       = var.tokyo_rds_endpoint
}

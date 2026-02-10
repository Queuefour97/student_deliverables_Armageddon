# Explanation: Outputs are your mission report—what got built and where to find it.
output "armageddon_vpc_id" {
  value = aws_vpc.armageddon_vpc01.id
}

output "armageddon_public_subnet_ids" {
  value = aws_subnet.armageddon_public_subnets[*].id
}

output "armageddon_private_subnet_ids" {
  value = aws_subnet.armageddon_private_subnets[*].id
}

output "armageddon_ec2_instance_id" {
  value = aws_instance.armageddon_ec201.id
}

output "armageddon_rds_endpoint" {
  value = aws_db_instance.armageddon_rds01.address
}

output "armageddon_sns_topic_arn" {
  value = aws_sns_topic.armageddon_sns_topic01.arn
}

output "armageddon_log_group_name" {
  value = aws_cloudwatch_log_group.armageddon_log_group01.name
}

output "armageddon_route53_zone_id" {
  value = local.armageddon_zone_id
}

output "armageddon_app_url_https" {
  value = "https://${var.app_subdomain}.${var.domain_name}"
}

# Explanation: The apex URL is the front gate—humans type this when they forget subdomains.
output "armageddon_apex_url_https" {
  value = "https://${var.domain_name}"
}

# Explanation: Log bucket name is where the footprints live—useful when hunting 5xx or WAF blocks.
output "armageddon_alb_logs_bucket_name" {
  value = var.enable_alb_access_logs ? aws_s3_bucket.armageddon_alb_logs_bucket01[0].bucket : null
}
output "armageddon_waf_log_destination" {
  value = var.waf_log_destination
}

# output "armageddon_waf_cw_log_group_name" {
#   value = var.waf_log_destination == "cloudwatch" ? aws_cloudwatch_log_group.armageddon_waf_log_group01[0].name : null
# }

output "armageddon_waf_logs_s3_bucket" {
  value = var.waf_log_destination == "s3" ? aws_s3_bucket.armageddon_waf_logs_bucket01[0].bucket : null
}


# output "armageddon_waf_firehose_name" {
#   value = var.waf_log_destination == "firehose" ? aws_kinesis_firehose_delivery_stream.armageddon_waf_firehose01[0].name : null
# }


#################################################
# output "instance_id" {
#   value = aws_instance.armageddon_ec201.id
# }

# #Bonus-A outputs (append to outputs.tf)

# # Explanation: These outputs prove Chewbacca built private hyperspace lanes (endpoints) instead of public chaos.
# output "armageddon_vpce_ssm_id" {
#   value = aws_vpc_endpoint.armageddon_vpce_ssm01.id
# }

# output "armageddon_vpce_logs_id" {
#   value = aws_vpc_endpoint.armageddon_vpce_logs01.id
# }

# output "armageddon_vpce_secrets_id" {
#   value = aws_vpc_endpoint.armageddon_vpce_secrets01.id
# }

# output "armageddon_vpce_s3_id" {
#   value = aws_vpc_endpoint.armageddon_vpce_s3_gw01.id
# }

# output "armageddon_private_ec2_instance_id_bonus" {
#   value = aws_instance.armageddon_ec201_private_bonus.id
# }

# output "armageddon_vpce_ec2messages_id" {
#   value = aws_vpc_endpoint.armageddon_vpce_ec2messages01.id
# }

# output "armageddon_vpce_ssmmessages_id" {
#   value = aws_vpc_endpoint.armageddon_vpce_ssmmessages01.id
# }
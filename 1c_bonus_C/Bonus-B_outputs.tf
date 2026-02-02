# # Explanation: Outputs are the mission coordinates — where to point your browser and your blasters.
# output "armageddon_alb_dns_name" {
#   value = aws_lb.armageddon_alb01.dns_name
# }

# output "armageddon_app_fqdn" {
#   value = "${var.app_subdomain}.${var.domain_name}"
# }

# output "armageddon_target_group_arn" {
#   value = aws_lb_target_group.armageddon_tg01.arn
# }

# output "armageddon_acm_cert_arn" {
#   value = aws_acm_certificate.armageddon_acm_cert01.arn
# }

# output "armageddon_waf_arn" {
#   value = var.enable_waf ? aws_wafv2_web_acl.armageddon_waf01[0].arn : null
# }

# output "armageddon_dashboard_name" {
#   value = aws_cloudwatch_dashboard.armageddon_dashboard01.dashboard_name
# }
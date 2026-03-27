############################################
# Sao Paulo main.tf
# Naming convention: liberdade-* (Bairro Liberdade,
# the Japanese district in Sao Paulo)
#
# Lab 3A: This is STATELESS COMPUTE ONLY.
# NO RDS - all reads/writes go to Tokyo via TGW.
# NO DB subnet group.
# NO RDS security group.
# YES: VPC, subnets, NAT, EC2, ALB, ASG, CloudFront.
# YES: Transit Gateway (spoke).
# YES: SSM params point to Tokyo RDS endpoint.
############################################

locals {
  name_prefix = var.project_name

  # FQDN locals (used in sao_paulo_alb_waf_monitoring.tf, sao_paulo_route53.tf)
  liberdale_fqdn     = "${var.app_subdomain}.${var.domain_name}"
  liberdale_app_fqdn = "${var.app_subdomain}.${var.domain_name}"

  # Route53 locals (used in sao_paulo_route53.tf)
  liberdale_zone_name = var.domain_name
  liberdale_zone_id   = var.manage_route53_in_terraform ? aws_route53_zone.liberdale_zone01[0].zone_id : var.route53_hosted_zone_id

  # VPC endpoint / IAM locals (used in sao_paulo_vpc_endpoints.tf)
  liberdale_prefix           = var.project_name
  liberdale_secret_arn_guess = "arn:aws:secretsmanager:${data.aws_region.liberdale_region01.id}:${data.aws_caller_identity.liberdale_self01.account_id}:secret:${var.project_name}/rds/mysql*"
}

############################################
# VPC + Internet Gateway
############################################

resource "aws_vpc" "liberdale_vpc01" {
  cidr_block           = var.vpc_cidr # 10.200.0.0/16 - no CIDR overlap with Tokyo
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.name_prefix}-vpc01" }
}

resource "aws_internet_gateway" "liberdale_igw01" {
  vpc_id = aws_vpc.liberdale_vpc01.id
  tags   = { Name = "${local.name_prefix}-igw01" }
}

############################################
# Subnets (Public + Private)
############################################

resource "aws_subnet" "liberdale_public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.liberdale_vpc01.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-subnet0${count.index + 1}" }
}

resource "aws_subnet" "liberdale_private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.liberdale_vpc01.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = { Name = "${local.name_prefix}-private-subnet0${count.index + 1}" }
}

############################################
# NAT Gateway + EIP
############################################

resource "aws_eip" "liberdale_nat_eip01" {
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip01" }
}

resource "aws_nat_gateway" "liberdale_nat01" {
  allocation_id = aws_eip.liberdale_nat_eip01.id
  subnet_id     = aws_subnet.liberdale_public_subnets[0].id
  depends_on    = [aws_internet_gateway.liberdale_igw01]
  tags          = { Name = "${local.name_prefix}-nat01" }
}

############################################
# Route Tables
############################################

resource "aws_route_table" "liberdale_public_rt01" {
  vpc_id = aws_vpc.liberdale_vpc01.id
  tags   = { Name = "${local.name_prefix}-public-rt01" }
}

resource "aws_route" "liberdale_public_default_route" {
  route_table_id         = aws_route_table.liberdale_public_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.liberdale_igw01.id
}

resource "aws_route_table_association" "liberdale_public_rta" {
  count          = length(aws_subnet.liberdale_public_subnets)
  subnet_id      = aws_subnet.liberdale_public_subnets[count.index].id
  route_table_id = aws_route_table.liberdale_public_rt01.id
}

resource "aws_route_table" "liberdale_private_rt01" {
  vpc_id = aws_vpc.liberdale_vpc01.id
  tags   = { Name = "${local.name_prefix}-private-rt01" }
}

resource "aws_route" "liberdale_private_default_route" {
  route_table_id         = aws_route_table.liberdale_private_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.liberdale_nat01.id
}

resource "aws_route_table_association" "liberdale_private_rta" {
  count          = length(aws_subnet.liberdale_private_subnets)
  subnet_id      = aws_subnet.liberdale_private_subnets[count.index].id
  route_table_id = aws_route_table.liberdale_private_rt01.id
}

############################################
# Security Groups
# FIX: EC2 SG had open inbound 0.0.0.0/0 on all ports.
#      Replaced with specific rules: port 80 from ALB SG
#      and port 22 from my_ip only.
############################################

resource "aws_security_group" "liberdale_ec2_sg01" {
  name        = "${local.name_prefix}-ec2-sg01"
  description = "EC2 app security group - inbound from ALB only"
  vpc_id      = aws_vpc.liberdale_vpc01.id

  # Inbound port 80 from ALB added via aws_security_group_rule in bonus_b.tf
  # Inbound port 22 from your IP added below

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound (includes TGW path to Tokyo RDS on 3306)"
  }

  tags = { Name = "${local.name_prefix}-ec2-sg01" }
}

resource "aws_vpc_security_group_ingress_rule" "ingress_22" {
  security_group_id = aws_security_group.liberdale_ec2_sg01.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
  description       = "SSH from admin IP"
}

# NOTE: Sao Paulo has NO RDS, NO rds_sg, NO db_subnet_group.
# The RDS SG that existed in Lab 2 is intentionally removed.
# Sao Paulo EC2 connects to Tokyo RDS via TGW - outbound 3306
# is already covered by the egress rule above.

############################################
# IAM Role + Instance Profile
############################################

resource "aws_iam_role" "liberdale_ec2_role01" {
  name = "${local.name_prefix}-ec2-role01"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "liberdale_ec2_ssm_attach" {
  role       = aws_iam_role.liberdale_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "liberdale_ec2_secrets_attach" {
  role       = aws_iam_role.liberdale_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "liberdale_ec2_cw_attach" {
  role       = aws_iam_role.liberdale_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "liberdale_instance_profile01" {
  name = "${local.name_prefix}-instance-profile01"
  role = aws_iam_role.liberdale_ec2_role01.name
}

############################################
# EC2 Instance
############################################

resource "aws_instance" "liberdale_ec201" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.liberdale_private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.liberdale_ec2_sg01.id]
  iam_instance_profile   = aws_iam_instance_profile.liberdale_instance_profile01.name
  user_data              = file("${path.module}/user_data.sh")

  tags = { Name = "${local.name_prefix}-ec201" }
}

############################################
# SSM Parameters - point to TOKYO RDS
# Sao Paulo stores the Tokyo endpoint here so
# the app reads it at runtime identically to
# how it would read a local endpoint. No code
# changes required in app.py.
############################################

resource "aws_ssm_parameter" "liberdale_db_endpoint_param" {
  name        = "/lab/db/endpoint"
  type        = "String"
  value       = var.tokyo_rds_endpoint # Tokyo RDS endpoint - populated from remote state
  description = "Tokyo RDS endpoint (cross-region via TGW)"
  tags        = { Name = "${local.name_prefix}-param-db-endpoint" }
}

resource "aws_ssm_parameter" "liberdale_db_port_param" {
  name  = "/lab/db/port"
  type  = "String"
  value = tostring(var.tokyo_rds_port)
  tags  = { Name = "${local.name_prefix}-param-db-port" }
}

resource "aws_ssm_parameter" "liberdale_db_name_param" {
  name  = "/lab/db/name"
  type  = "String"
  value = "labdb"
  tags  = { Name = "${local.name_prefix}-param-db-name" }
}

############################################
# CloudWatch Log Group
############################################

resource "aws_cloudwatch_log_group" "liberdale_log_group01" {
  name              = "/aws/ec2/${local.name_prefix}-rds-app"
  retention_in_days = 7
  tags              = { Name = "${local.name_prefix}-log-group01" }
}

############################################
# CloudWatch Alarm (DB connectivity)
############################################

resource "aws_cloudwatch_metric_alarm" "liberdale_db_alarm01" {
  alarm_name          = "${local.name_prefix}-db-connection-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DBConnectionErrors"
  namespace           = "Lab/RDSApp"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.liberdale_sns_topic01.arn]
  tags                = { Name = "${local.name_prefix}-alarm-db-fail" }
}

############################################
# SNS
############################################

resource "aws_sns_topic" "liberdale_sns_topic01" {
  name = "${local.name_prefix}-db-incidents"
}

resource "aws_sns_topic_subscription" "liberdale_sns_sub01" {
  topic_arn = aws_sns_topic.liberdale_sns_topic01.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}

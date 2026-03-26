############################################
# tokyo_main.tf
# Naming convention: shinjuku-* (新宿 - Tokyo train station)
#
# Tokyo is the DATA AUTHORITY for this architecture.
# APPI (個人情報保護法) compliance requires all PHI
# to be stored physically inside Japan.
#
# ✅ VPC, subnets, NAT, EC2
# ✅ RDS MySQL (PHI lives here and ONLY here)
# ✅ RDS subnet group + security group
# ✅ Parameter Store (DB endpoint, port, name)
# ✅ Secrets Manager (DB credentials)
# ✅ IAM role + instance profile
# ✅ CloudWatch log group + alarm
# ✅ SNS topic + email subscription
#
# Lab 3A additions are in separate files:
#   tokyo_tgw.tf     - Transit Gateway hub + peering request
#   tokyo_routes.tf  - Return routes for Sao Paulo CIDR
#   aws_security_group.shinjuku_rds_sg01.tf - RDS SG rule for SP CIDR
############################################

locals {
  name_prefix = var.project_name # "shinjuku-final"

  # FQDN locals (used in tokyo_alb_waf_monitoring.tf, tokyo_route53.tf)
  shinjuku_fqdn     = "${var.app_subdomain}.${var.domain_name}"
  shinjuku_app_fqdn = "${var.app_subdomain}.${var.domain_name}"

  # Route53 locals (used in tokyo_route53.tf)
  shinjuku_zone_name = var.domain_name
  shinjuku_zone_id   = var.manage_route53_in_terraform ? aws_route53_zone.shinjuku_zone01[0].zone_id : var.route53_hosted_zone_id

  # VPC endpoint / IAM locals (used in tokyo_vpc_endpoints.tf)
  shinjuku_prefix          = var.project_name
  shinjuku_secret_arn_guess = "arn:aws:secretsmanager:${data.aws_region.shinjuku_region01.id}:${data.aws_caller_identity.shinjuku_self01.account_id}:secret:${var.project_name}/rds/mysql*"
}

# Required by tokyo_tgw.tf:
# peer_account_id = data.aws_caller_identity.shinjuku_self01.account_id
data "aws_caller_identity" "shinjuku_self01" {}

############################################
# VPC + Internet Gateway
############################################

resource "aws_vpc" "shinjuku_vpc01" {
  cidr_block           = var.vpc_cidr # 10.100.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true # Required for RDS DNS resolution across TGW

  tags = { Name = "${local.name_prefix}-vpc01" }
}

resource "aws_internet_gateway" "shinjuku_igw01" {
  vpc_id = aws_vpc.shinjuku_vpc01.id
  tags   = { Name = "${local.name_prefix}-igw01" }
}

############################################
# Subnets (Public + Private)
############################################

resource "aws_subnet" "shinjuku_public_subnets" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.shinjuku_vpc01.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.azs[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${local.name_prefix}-public-subnet0${count.index + 1}" }
}

resource "aws_subnet" "shinjuku_private_subnets" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = aws_vpc.shinjuku_vpc01.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.azs[count.index]

  tags = { Name = "${local.name_prefix}-private-subnet0${count.index + 1}" }
}

############################################
# NAT Gateway + EIP
############################################

resource "aws_eip" "shinjuku_nat_eip01" {
  domain = "vpc"
  tags   = { Name = "${local.name_prefix}-nat-eip01" }
}

resource "aws_nat_gateway" "shinjuku_nat01" {
  allocation_id = aws_eip.shinjuku_nat_eip01.id
  subnet_id     = aws_subnet.shinjuku_public_subnets[0].id
  depends_on    = [aws_internet_gateway.shinjuku_igw01]
  tags          = { Name = "${local.name_prefix}-nat01" }
}

############################################
# Route Tables (Public + Private)
# NOTE: The cross-region TGW route for Sao Paulo
# is added in tokyo_routes.tf, not here.
############################################

resource "aws_route_table" "shinjuku_public_rt01" {
  vpc_id = aws_vpc.shinjuku_vpc01.id
  tags   = { Name = "${local.name_prefix}-public-rt01" }
}

resource "aws_route" "shinjuku_public_default_route" {
  route_table_id         = aws_route_table.shinjuku_public_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.shinjuku_igw01.id
}

resource "aws_route_table_association" "shinjuku_public_rta" {
  count          = length(aws_subnet.shinjuku_public_subnets)
  subnet_id      = aws_subnet.shinjuku_public_subnets[count.index].id
  route_table_id = aws_route_table.shinjuku_public_rt01.id
}

resource "aws_route_table" "shinjuku_private_rt01" {
  vpc_id = aws_vpc.shinjuku_vpc01.id
  tags   = { Name = "${local.name_prefix}-private-rt01" }
}

resource "aws_route" "shinjuku_private_default_route" {
  route_table_id         = aws_route_table.shinjuku_private_rt01.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.shinjuku_nat01.id
}

resource "aws_route_table_association" "shinjuku_private_rta" {
  count          = length(aws_subnet.shinjuku_private_subnets)
  subnet_id      = aws_subnet.shinjuku_private_subnets[count.index].id
  route_table_id = aws_route_table.shinjuku_private_rt01.id
}

############################################
# Security Groups
# FIX: Original EC2 SG had ingress 0.0.0.0/0 all
#      ports wide open. Replaced with explicit rules:
#      port 80 from ALB SG (added in bonus_b.tf),
#      port 22 from my_ip only (added below).
############################################

resource "aws_security_group" "shinjuku_ec2_sg01" {
  name        = "${local.name_prefix}-ec2-sg01"
  description = "EC2 app security group - inbound rules managed via separate rule resources"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  # DO NOT add ingress blocks here.
  # Port 80 from ALB SG → added in bonus_b.tf via aws_security_group_rule
  # Port 22 from my_ip  → added below via aws_vpc_security_group_ingress_rule
  # Adding an ingress block here that references shinjuku_alb_sg01 will fail
  # because that SG is declared in bonus_b.tf, not in this file.

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${local.name_prefix}-ec2-sg01" }
}

resource "aws_vpc_security_group_ingress_rule" "ingress_22" {
  security_group_id = aws_security_group.shinjuku_ec2_sg01.id
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = var.my_ip
  description       = "SSH from admin IP only"
}

############################################
# RDS Security Group
# Inbound 3306 from:
#   - Tokyo EC2 SG (same VPC, SG reference)
#   - Sao Paulo VPC CIDR (cross-region via TGW,
#     added in aws_security_group.shinjuku_rds_sg01.tf
#     because SG references don't work cross-VPC)
############################################

resource "aws_security_group" "shinjuku_rds_sg01" {
  name        = "${local.name_prefix}-rds-sg01"
  description = "RDS security group - MySQL inbound from Tokyo EC2 and Sao Paulo VPC CIDR"
  vpc_id      = aws_vpc.shinjuku_vpc01.id

  ingress {
    description     = "MySQL from Tokyo EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.shinjuku_ec2_sg01.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = { Name = "${local.name_prefix}-rds-sg01" }
}

# Sao Paulo CIDR ingress rule lives in:
# aws_security_group.shinjuku_rds_sg01.tf
# (kept separate so Lab 2 and Lab 3A changes are clearly distinct)

############################################
# RDS Subnet Group
############################################

resource "aws_db_subnet_group" "shinjuku_rds_subnet_group01" {
  name       = "${local.name_prefix}-rds-subnet-group01"
  subnet_ids = aws_subnet.shinjuku_private_subnets[*].id
  tags       = { Name = "${local.name_prefix}-rds-subnet-group01" }
}

############################################
# RDS Instance (MySQL)
# This is the ONLY database in the architecture.
# All reads and writes from Sao Paulo come here
# via Transit Gateway. Data never leaves Japan.
############################################

resource "aws_db_instance" "shinjuku_rds01" {
  identifier        = "${local.name_prefix}-rds01"
  engine            = var.db_engine            # mysql
  instance_class    = var.db_instance_class    # db.t3.micro
  allocated_storage = 20
  db_name           = var.db_name              # labdb
  username          = var.db_username
  password          = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.shinjuku_rds_subnet_group01.name
  vpc_security_group_ids = [aws_security_group.shinjuku_rds_sg01.id]

  publicly_accessible = false # APPI: never expose PHI database publicly
  skip_final_snapshot = true

  tags = { Name = "${local.name_prefix}-rds01" }
}

############################################
# IAM Role + Instance Profile
############################################

resource "aws_iam_role" "shinjuku_ec2_role01" {
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

resource "aws_iam_role_policy_attachment" "shinjuku_ec2_ssm_attach" {
  role       = aws_iam_role.shinjuku_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "shinjuku_ec2_secrets_attach" {
  role       = aws_iam_role.shinjuku_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}

resource "aws_iam_role_policy_attachment" "shinjuku_ec2_cw_attach" {
  role       = aws_iam_role.shinjuku_ec2_role01.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "shinjuku_instance_profile01" {
  name = "${local.name_prefix}-instance-profile01"
  role = aws_iam_role.shinjuku_ec2_role01.name
}

############################################
# EC2 Instance
############################################

resource "aws_instance" "shinjuku_ec201" {
  ami                    = var.ec2_ami_id
  instance_type          = var.ec2_instance_type
  subnet_id              = aws_subnet.shinjuku_private_subnets[0].id
  vpc_security_group_ids = [aws_security_group.shinjuku_ec2_sg01.id]
  iam_instance_profile   = aws_iam_instance_profile.shinjuku_instance_profile01.name
  user_data              = file("${path.module}/user_data.sh")

  tags = { Name = "${local.name_prefix}-ec201" }
}

############################################
# Parameter Store (SSM)
# Tokyo writes its OWN RDS endpoint here.
# Sao Paulo writes the SAME parameter path
# in sa-east-1 pointing to this same endpoint.
# Both app deployments use identical app.py code.
############################################

resource "aws_ssm_parameter" "shinjuku_db_endpoint_param" {
  name  = "/lab/db/endpoint"
  type  = "String"
  value = aws_db_instance.shinjuku_rds01.address
  tags  = { Name = "${local.name_prefix}-param-db-endpoint" }
}

resource "aws_ssm_parameter" "shinjuku_db_port_param" {
  name  = "/lab/db/port"
  type  = "String"
  value = tostring(aws_db_instance.shinjuku_rds01.port)
  tags  = { Name = "${local.name_prefix}-param-db-port" }
}

resource "aws_ssm_parameter" "shinjuku_db_name_param" {
  name  = "/lab/db/name"
  type  = "String"
  value = var.db_name
  tags  = { Name = "${local.name_prefix}-param-db-name" }
}

############################################
# Secrets Manager (DB Credentials)
# FIX: Secret name changed from "{prefix}/rds/mysql1"
# to match the SECRET_ID env var in user_data.sh.
# app.py reads SECRET_ID from the systemd environment
# so the name is consistent and not hardcoded in Python.
############################################

resource "aws_secretsmanager_secret" "shinjuku_db_secret01" {
  name                    = "${local.name_prefix}/rds/mysql1"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "shinjuku_db_secret_version01" {
  secret_id = aws_secretsmanager_secret.shinjuku_db_secret01.id

  secret_string = jsonencode({
    username = var.db_username
    password = var.db_password
    host     = aws_db_instance.shinjuku_rds01.address
    port     = aws_db_instance.shinjuku_rds01.port
    dbname   = var.db_name
  })
}

############################################
# CloudWatch Log Group
############################################

resource "aws_cloudwatch_log_group" "shinjuku_log_group01" {
  name              = "/aws/ec2/${local.name_prefix}-rds-app"
  retention_in_days = 7
  tags              = { Name = "${local.name_prefix}-log-group01" }
}

############################################
# CloudWatch Alarm (DB connection failures)
############################################

resource "aws_cloudwatch_metric_alarm" "shinjuku_db_alarm01" {
  alarm_name          = "${local.name_prefix}-db-connection-failure"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "DBConnectionErrors"
  namespace           = "Lab/RDSApp"
  period              = 300
  statistic           = "Sum"
  threshold           = 3
  alarm_actions       = [aws_sns_topic.shinjuku_sns_topic01.arn]
  tags                = { Name = "${local.name_prefix}-alarm-db-fail" }
}

############################################
# SNS Topic + Email Subscription
############################################

resource "aws_sns_topic" "shinjuku_sns_topic01" {
  name = "${local.name_prefix}-db-incidents"
}

resource "aws_sns_topic_subscription" "shinjuku_sns_sub01" {
  topic_arn = aws_sns_topic.shinjuku_sns_topic01.arn
  protocol  = "email"
  endpoint  = var.sns_email_endpoint
}

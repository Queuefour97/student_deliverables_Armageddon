############################################
# Lab 3A — RDS Security Group: Allow São Paulo
# File: aws_security_group.shinjuku_rds_sg01.tf
#
# APPI COMPLIANCE NOTE:
# SG referencing doesn't work cross-VPC/cross-region.
# The correct pattern is CIDR-based ingress from
# the São Paulo VPC CIDR. This is intentional and
# documented — it is the standard enterprise pattern
# for TGW-connected multi-region architectures.
#
# This grants inbound MySQL 3306 from the entire
# São Paulo VPC CIDR. For stricter control, narrow
# to the São Paulo private subnet CIDRs only.
############################################

resource "aws_security_group_rule" "shinjuku_rds_ingress_from_saopaulo" {
  type              = "ingress"
  security_group_id = aws_security_group.shinjuku_rds_sg01.id
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  cidr_blocks       = [var.saopaulo_vpc_cidr]
  description       = "Allow MySQL from Sao Paulo VPC via TGW Lab 3A cross-region"
}

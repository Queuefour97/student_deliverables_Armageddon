############################################
# Lab 3A - Tokyo Transit Gateway (Hub)
# File: tokyo_tgw.tf
#
# Naming: shinjuku-* (Tokyo train station theme)
# Tokyo is the TGW hub. Sao Paulo is the spoke.
# All PHI stays in Tokyo - this is the network
# that makes cross-region RDS access possible
# without ever moving data to Sao Paulo.
############################################

############################################
# Tokyo Transit Gateway
############################################

resource "aws_ec2_transit_gateway" "shinjuku_tgw01" {
  description                     = "shinjuku-tgw01: Tokyo hub for cross-region PHI corridor"
  amazon_side_asn                 = 64512 # Tokyo uses ASN 64512; Sao Paulo uses 64513
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "disable" # Explicit acceptance required - auditable

  tags = {
    Name   = "shinjuku-tgw01"
    Region = "ap-northeast-1"
    Role   = "hub"
  }
}

############################################
# Tokyo VPC Attachment to TGW
############################################

resource "aws_ec2_transit_gateway_vpc_attachment" "shinjuku_tgw_vpc_attach01" {
  transit_gateway_id = aws_ec2_transit_gateway.shinjuku_tgw01.id
  vpc_id             = aws_vpc.shinjuku_vpc01.id

  # Attach private subnets - TGW ENIs live here
  # Public subnets don't need TGW; PHI traffic is private-only
  subnet_ids = aws_subnet.shinjuku_private_subnets[*].id

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = {
    Name = "shinjuku-tgw-vpc-attach01"
  }
}

############################################
# TGW Peering Request → Sao Paulo
#
# This is the cross-region peering attachment.
# Tokyo INITIATES; Sao Paulo ACCEPTS.
# Both TGWs must exist before the peering can
# be accepted. In a real pipeline:
#   1. Apply Tokyo first (creates peering request)
#   2. Apply Sao Paulo (accepts + routes)
############################################

resource "aws_ec2_transit_gateway_peering_attachment" "shinjuku_tgw_peering01" {
  transit_gateway_id      = aws_ec2_transit_gateway.shinjuku_tgw01.id
  peer_transit_gateway_id = var.saopaulo_tgw_id   # Consumed from Sao Paulo remote state
  peer_region             = "sa-east-1"
  peer_account_id         = data.aws_caller_identity.shinjuku_self01.account_id

  tags = {
    Name = "shinjuku-tgw-peering-to-saopaulo01"
    Side = "requester"
  }
}

############################################
# Static route: Sao Paulo CIDR -> TGW peering
#
# IMPORTANT: This route can only be created AFTER
# Sao Paulo has accepted the peering attachment.
# The peering must be in "available" state first.
#
# count = 0 during the initial Tokyo apply (peering
# is still "pendingAcceptance"). After Sao Paulo
# accepts, re-apply Tokyo with:
#   terraform apply \
#     -var="saopaulo_tgw_id=tgw-0abc..." \
#     -var="tgw_peering_accepted=true"
############################################

variable "tgw_peering_accepted" {
  description = "Set to true only after Sao Paulo has accepted the TGW peering attachment. Prevents route creation while peering is still in pendingAcceptance state."
  type        = bool
  default     = false
}

resource "aws_ec2_transit_gateway_route" "shinjuku_tgw_route_to_saopaulo01" {
  count = var.tgw_peering_accepted ? 1 : 0

  transit_gateway_route_table_id = aws_ec2_transit_gateway.shinjuku_tgw01.association_default_route_table_id
  destination_cidr_block         = var.saopaulo_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment.shinjuku_tgw_peering01.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment.shinjuku_tgw_peering01]
}

# Variable for Sao Paulo TGW ID (populated from Sao Paulo remote state output)
variable "saopaulo_tgw_id" {
  description = "Sao Paulo TGW ID - read from saopaulo remote state after Sao Paulo first apply."
  type        = string
  default     = "" # Students replace with actual TGW ID after Sao Paulo first apply
}

############################################
# Lab 3A - Sao Paulo Transit Gateway (Spoke)
# File: sao_paulo_tgw.tf
#
# Sao Paulo is the spoke. It:
#   1. Creates its own TGW (TGWs are regional)
#   2. Accepts the peering request from Tokyo
#   3. Attaches its VPC to its local TGW
#
# Peering flow:
#   Tokyo TGW  ──[peering request]──▶  Sao Paulo TGW
#                ◀──[accept]──
############################################

############################################
# Sao Paulo Transit Gateway
############################################

resource "aws_ec2_transit_gateway" "liberdale_tgw01" {
  description                     = "liberdale-tgw01: Sao Paulo spoke - compute-only, no PHI"
  amazon_side_asn                 = 64513 # Sao Paulo uses 64513; Tokyo uses 64512 (must differ)
  default_route_table_association = "enable"
  default_route_table_propagation = "enable"
  auto_accept_shared_attachments  = "disable"

  tags = {
    Name   = "liberdale-tgw01"
    Region = "sa-east-1"
    Role   = "spoke"
  }
}

############################################
# Accept TGW Peering from Tokyo
#
# The peering attachment was CREATED in Tokyo.
# Sao Paulo ACCEPTS it here.
# This resource is idempotent - it will sit in
# "pendingAcceptance" until the Tokyo attachment
# ID is provided.
############################################

resource "aws_ec2_transit_gateway_peering_attachment_accepter" "liberdale_tgw_peering_accept01" {
  transit_gateway_attachment_id = var.tokyo_tgw_peering_attachment_id

  tags = {
    Name = "liberdale-tgw-peering-from-tokyo01"
    Side = "accepter"
  }
}

############################################
# Sao Paulo VPC Attachment to TGW
############################################

resource "aws_ec2_transit_gateway_vpc_attachment" "liberdale_tgw_vpc_attach01" {
  transit_gateway_id = aws_ec2_transit_gateway.liberdale_tgw01.id
  vpc_id             = aws_vpc.liberdale_vpc01.id
  subnet_ids         = aws_subnet.liberdale_private_subnets[*].id

  dns_support  = "enable"
  ipv6_support = "disable"

  tags = { Name = "liberdale-tgw-vpc-attach01" }
}

############################################
# Static route: Tokyo CIDR → TGW peering
############################################

resource "aws_ec2_transit_gateway_route" "liberdale_tgw_route_to_tokyo01" {
  transit_gateway_route_table_id = aws_ec2_transit_gateway.liberdale_tgw01.association_default_route_table_id
  destination_cidr_block         = var.tokyo_vpc_cidr
  transit_gateway_attachment_id  = aws_ec2_transit_gateway_peering_attachment_accepter.liberdale_tgw_peering_accept01.id

  depends_on = [aws_ec2_transit_gateway_peering_attachment_accepter.liberdale_tgw_peering_accept01]
}

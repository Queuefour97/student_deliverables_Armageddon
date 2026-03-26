############################################
# Lab 3A — São Paulo Route Table Updates
# File: sao_paulo_routes.tf
#
# Add routes in São Paulo private subnets:
#   Destination: Tokyo VPC CIDR
#   Target:      São Paulo TGW
#
# This is the forward path for RDS traffic:
#   SP EC2 → SP private RT → SP TGW → TGW peering
#   → Tokyo TGW → Tokyo private subnet → Tokyo RDS
############################################

resource "aws_route" "liberdale_private_to_tokyo" {
  route_table_id         = aws_route_table.liberdale_private_rt01.id
  destination_cidr_block = var.tokyo_vpc_cidr  # 10.100.0.0/16
  transit_gateway_id     = aws_ec2_transit_gateway.liberdale_tgw01.id

  depends_on = [aws_ec2_transit_gateway_vpc_attachment.liberdale_tgw_vpc_attach01]
}

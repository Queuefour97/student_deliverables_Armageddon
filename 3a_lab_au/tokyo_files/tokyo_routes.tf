############################################
# Lab 3A — Tokyo Route Table Updates
# File: tokyo_routes.tf
#
# Add return routes for São Paulo CIDR pointing
# to the Tokyo TGW. Without these, packets from
# Tokyo RDS will have no path back to São Paulo EC2.
#
# Rule: Tokyo private subnets → São Paulo CIDR → TGW
############################################

# Route: Tokyo private subnet → São Paulo VPC CIDR → Tokyo TGW
# This is the return path for RDS responses headed back to São Paulo.
resource "aws_route" "shinjuku_private_to_saopaulo" {
  route_table_id         = aws_route_table.shinjuku_private_rt01.id
  destination_cidr_block = var.saopaulo_vpc_cidr
  transit_gateway_id     = aws_ec2_transit_gateway.shinjuku_tgw01.id

  # TGW VPC attachment must exist before routes can reference the TGW
  depends_on = [aws_ec2_transit_gateway_vpc_attachment.shinjuku_tgw_vpc_attach01]
}

# If you have a second private route table (multi-AZ), add it here.
# resource "aws_route" "shinjuku_private_rt02_to_saopaulo" {
#   route_table_id         = aws_route_table.shinjuku_private_rt02.id
#   destination_cidr_block = var.saopaulo_vpc_cidr
#   transit_gateway_id     = aws_ec2_transit_gateway.shinjuku_tgw01.id
#   depends_on             = [aws_ec2_transit_gateway_vpc_attachment.shinjuku_tgw_vpc_attach01]
# }

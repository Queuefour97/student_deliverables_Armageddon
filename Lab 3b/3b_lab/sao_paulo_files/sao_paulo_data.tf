############################################
# São Paulo data.tf
# Reads outputs from Tokyo remote state.
#
# In a multi-state pipeline, this is how São Paulo
# learns the Tokyo TGW ID, VPC CIDR, and RDS endpoint
# without hardcoding them.
#
# Usage: either use this data source OR pass values
# as variables via -var-file. Both are valid. The
# remote state approach is preferred for automation.
#
# Uncomment and configure the backend block below
# when your Tokyo state is stored in S3.
############################################

# data "terraform_remote_state" "tokyo" {
#   backend = "s3"
#   config = {
#     bucket = "your-tfstate-bucket"
#     key    = "lab3/tokyo/terraform.tfstate"
#     region = "ap-northeast-1"
#   }
# }
#
# Then in sao_paulo_tgw.tf, replace var.tokyo_tgw_peering_attachment_id with:
#   data.terraform_remote_state.tokyo.outputs.tokyo_tgw_peering_attachment_id
#
# And in main.tf, replace var.tokyo_rds_endpoint with:
#   data.terraform_remote_state.tokyo.outputs.shinjuku_rds_endpoint

data "aws_caller_identity" "liberdale_self01" {}
data "aws_region" "liberdale_region01" {}

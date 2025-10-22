# INFO: ASG instances can spin up without a NATGW because there's an S3 gateway (vpc_endpoint.tf) in this configuration.
# This is because Amazon Linux 2023 AMI uses S3 for the yum repo.
# If you plan on using NATGWs for the ASG instances when modifying the cloud-init script then set natgw = true and you'll need to add an egress security group rule to the instances security group.
# for example this security group rule would allow https outbound to the internet:
# resource "aws_security_group_rule" "instance_egress_allow_443_to_internet" {
#   security_group_id = aws_security_group.instance.id
#   cidr_blocks       = ["0.0.0.0/0"]
#   type              = "egress"
#   from_port         = 443
#   to_port           = 443
#   protocol          = "tcp"
# }
#
# NOTE: Using isolated subnets for db subnets for future use when scaling VPCs in a Centralized Router (TGW hub and spoke).
# It will make it easier for db connections to be same VPC only so other intra region VPCs cant connect when full mesh TGW routes exist.
# example: https://github.com/JudeQuintana/terraform-main/tree/main/centralized_egress_dual_stack_full_mesh_trio_demo
locals {
  vpcs = [
    {
      name = "app"
      ipv4 = {
        network_cidr = "10.0.0.0/18"
        ipam_pool    = local.ipv4_ipam_pool
      }
      azs = {
        a = {
          isolated_subnets = [
            { name = "db1", cidr = "10.0.1.0/24" }
          ]
          private_subnets = [
            { name = "proxy1", cidr = "10.0.2.0/24" }
          ]
          public_subnets = [
            { name = "lb1", cidr = "10.0.3.0/28", natgw = false }
          ]
        }
        b = {
          isolated_subnets = [
            { name = "db2", cidr = "10.0.7.0/24" }
          ]
          private_subnets = [
            { name = "proxy2", cidr = "10.0.8.0/24" }
          ]
          public_subnets = [
            { name = "lb2", cidr = "10.0.9.0/28", natgw = false }
          ]
        }
      }
    }
  ]
}

# source = https://github.com/JudeQuintana/terraform-aws-tiered-vpc-ng/tree/v1.0.7
module "vpcs" {
  source  = "JudeQuintana/tiered-vpc-ng/aws"
  version = "1.0.7"

  for_each = { for this in local.vpcs : this.name => this }

  env_prefix       = var.env_prefix
  region_az_labels = var.region_az_labels
  tiered_vpc       = each.value
}

locals {
  vpc_names = { for this in local.vpcs : this.name => this.name }

  # for easier referencing the instansiated app vpc object in the demo
  # but generally would have the lookup(module.vpcs, local.vpc_names.app) everywhere
  # when there are several vpcs (usually double lookups)
  app_vpc = lookup(module.vpcs, local.vpc_names.app)
}


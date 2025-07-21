# ipam was set up manually (advanced tier)
# main ipam in usw2 with a pool for usw2 locale
data "aws_vpc_ipam_pool" "ipv4_usw2" {
  filter {
    name   = "description"
    values = ["ipv4-test-usw2"]
  }

  filter {
    name   = "address-family"
    values = ["ipv4"]
  }
}

locals {
  ipv4_ipam_pool_usw2 = data.aws_vpc_ipam_pool.ipv4_usw2

  # INFO: ASG instances can spin up without a NATGW because there's an S3 gateway (vpc_endpoint.tf) in this configuration.
  # This is because Amazon Linux 2023 AMI uses S3 for the yum repo.
  #
  # NOTE: Using isolated subnets for db subnets for future use when scaling VPCs in a Centralized Router (TGW hub and spoke).
  # It will make it easier for db connections to be same VPC only so other intra region VPCs cant connect when full mesh TGW routes exist.
  # example: https://github.com/JudeQuintana/terraform-main/tree/main/centralized_egress_dual_stack_full_mesh_trio_demo
  vpcs = [
    {
      name = "app"
      ipv4 = {
        network_cidr = "10.0.0.0/18"
        ipam_pool    = local.ipv4_ipam_pool_usw2
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
            { name = "lb1", cidr = "10.0.3.0/28", natgw = var.enable_natgws }
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
            { name = "lb2", cidr = "10.0.9.0/28", natgw = var.enable_natgws }
          ]
        }
      }
    }
  ]
}

module "vpcs" {
  source  = "JudeQuintana/tiered-vpc-ng/aws"
  version = "1.0.7"

  for_each = { for this in local.vpcs : this.name => this }

  env_prefix       = var.env_prefix
  region_az_labels = var.region_az_labels
  tiered_vpc       = each.value
}

locals {
  vpc_names = { for this in module.vpcs : this.name => this.name }
}


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

  # INFO: ASG can spin up without a NATWGW because there's an S3 gateway (vpc_endpoint.tf) in this configuration.
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
            { name = "lb1", cidr = "10.0.3.0/28", natgw = true }
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
            { name = "lb2", cidr = "10.0.9.0/28", natgw = true }
          ]
        }
      }
    }
  ]
}

module "vpcs" {
  source  = "JudeQuintana/tiered-vpc-ng/aws"
  version = "1.0.7"

  for_each = { for t in local.vpcs : t.name => t }

  env_prefix       = var.env_prefix
  region_az_labels = var.region_az_labels
  tiered_vpc       = each.value
}

locals {
  vpc_names = { for v in module.vpcs : v.name => v.name }
}

output "vpcs_natgw_eips_per_az" {
  value = { for v in module.vpcs : v.name => v.public_natgw_az_to_eip }
}


locals {
  # TODO: add IPAM to VPC and ALB
  tiered_vpcs = [
    {
      name         = "app"
      network_cidr = "10.0.0.0/20"
      azs = {
        a = {
          private_subnets = [
            { name = "proxy1", cidr = "10.0.1.0/24", special = true },
            { name = "db1", cidr = "10.0.2.0/24" } # should use isolated subnet but using private for now

          ]
          public_subnets = [
            { name = "lb1", cidr = "10.0.3.0/28", }
            #{ name = "lb1", cidr = "10.0.3.0/28", natgw = true }
          ]
        }
        b = {
          private_subnets = [
            { name = "proxy2", cidr = "10.0.7.0/24", special = true },
            { name = "db2", cidr = "10.0.8.0/24" } # should use isolated subnet but using private for now

          ]
          public_subnets = [
            #{ name = "lb2", cidr = "10.0.9.0/28", natgw = true }
            { name = "lb2", cidr = "10.0.9.0/28", }
          ]
        }
      }
    }
  ]
}

module "vpcs" {
  source  = "JudeQuintana/tiered-vpc-ng/aws"
  version = "1.0.1"

  for_each = { for t in local.tiered_vpcs : t.name => t }

  env_prefix       = var.env_prefix
  region_az_labels = var.region_az_labels
  tiered_vpc       = each.value
}

locals {
  tiered_vpc_names = { for v in module.vpcs : v.name => v.name }
}


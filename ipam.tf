locals {
  # enable one or the other but not both.
  global_ipam                = { for this in [var.enable_global_ipam] : this => this if var.enable_global_ipam }
  data_global_ipam_cidr_pool = { for this in [!var.enable_global_ipam] : this => this if !var.enable_global_ipam }
}

# if var.enable_global_ipam = `true`
module "global_ipam" {
  source = "./modules/ipam"

  for_each = local.global_ipam

  env_prefix = var.env_prefix
  ipam = {
    name            = "infra"
    provision_cidrs = ["10.0.0.0/18"]
  }
}

# if var.enable_global_ipam = `false`
# use pre-existing cidr pool via data read
# ipam was set up manually (advanced tier)
# main ipam in usw2 with a pool for usw2 locale
data "aws_vpc_ipam_pool" "ipv4_usw2" {
  for_each = local.data_global_ipam_cidr_pool

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
  ipv4_ipam_pool_usw2 = var.enable_global_ipam ? lookup(module.global_ipam, var.enable_global_ipam).ipv4_pool : lookup(data.aws_vpc_ipam_pool.ipv4_usw2, !var.enable_global_ipam)
}


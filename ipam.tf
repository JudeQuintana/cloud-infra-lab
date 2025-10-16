locals {
  # enable one or the other but not both.
  ipam                = { for this in [var.enable_ipam] : this => this if var.enable_ipam }
  data_ipam_cidr_pool = { for this in [!var.enable_ipam] : this => this if !var.enable_ipam }
}

# if var.enable_ipam = true
# create ipam, pools and provision cidrs
# prereq:
#  - no ipam exists in the `us-west-2` region
#  - no other ipam (in another regions) should provision the 10.0.0.0/18 CIDR
module "ipam" {
  source = "./modules/ipam"

  for_each = local.ipam

  env_prefix = var.env_prefix
  ipam = {
    name            = "infra"
    provision_cidrs = ["10.0.0.0/18"]
  }
}

# if var.enable_ipam = false (default)
# use pre-existing cidr pool via data read
# ipam was set up manually (advanced tier)
# main ipam in usw2 with a pool for usw2 locale
data "aws_vpc_ipam_pool" "ipv4" {
  for_each = local.data_ipam_cidr_pool

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
  ipv4_ipam_pool = var.enable_ipam ? lookup(module.ipam, var.enable_ipam).ipv4_pool : lookup(data.aws_vpc_ipam_pool.ipv4, !var.enable_ipam)
}


locals {
  url = format("%s%s/", "https://", local.domain_name)
}

output "url" {
  value = local.url
}

output "endpoint1" {
  value = format("%s%s", local.url, "app1")
}

output "endpoint2" {
  value = format("%s%s", local.url, "app2")
}

# show which VPC AZ have a NATGW enabled, demo default is none
output "vpcs_natgw_eips_per_az" {
  value = { for this in module.vpcs : this.name => this.public_natgw_az_to_eip if length(this.public_natgw_az_to_eip) > 0 }
}

output "asg_instance_refresh_enabled" {
  value = module.asg.instance_refresh
}

output "rds_proxy_enabled" {
  value = var.enable_rds_proxy
}

# display endpoints
output "rds_addresses" {
  value = module.rds
}


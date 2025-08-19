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

output "vpcs_natgw_eips_per_az" {
  value = { for this in module.vpcs : this.name => this.public_natgw_az_to_eip }
}

output "asg_instance_refresher_enabled" {
  value = var.asg_instance_refresher
}

output "rds_proxy_enabled" {
  value = var.rds_proxy
}


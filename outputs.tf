locals {
  url       = format("%s%s/", "https://", local.domain_name)
  endpoint1 = format("%s%s", local.url, "app1")
  endpoint2 = format("%s%s", local.url, "app2")
}

output "url" {
  value = local.url
}

output "endpoint1" {
  value = local.endpoint1
}

output "endpoint2" {
  value = local.endpoint2
}

output "vpcs_natgw_eips_per_az" {
  value = { for this in module.vpcs : this.name => this.public_natgw_az_to_eip }
}


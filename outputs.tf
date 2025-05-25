output "url" {
  value = format("%s%s", "https://", local.domain_name)
}

output "vpcs_natgw_eips_per_az" {
  value = { for this in module.vpcs : this.name => this.public_natgw_az_to_eip }
}


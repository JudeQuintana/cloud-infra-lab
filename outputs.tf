output "url" {
  value = format("%s%s", "https://", local.domain_name)
}

output "vpcs_natgw_eips_per_az" {
  value = { for v in module.vpcs : v.name => v.public_natgw_az_to_eip }
}


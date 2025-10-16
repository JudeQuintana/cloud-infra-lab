resource "aws_vpc_ipam_pool" "this_ipv4" {
  address_family = "ipv4"
  ipam_scope_id  = aws_vpc_ipam.this.private_default_scope_id
  locale         = local.region

  tags = merge(
    local.default_tags,
    { Name = local.ipam_name }
  )
}

resource "aws_vpc_ipam_pool_cidr" "this_ipv4" {
  for_each = local.provision_cidrs

  ipam_pool_id = aws_vpc_ipam_pool.this_ipv4.id
  cidr         = each.value
}


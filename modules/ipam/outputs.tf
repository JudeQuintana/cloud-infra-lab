
output "id" {
  value = aws_vpc_ipam.this.id
}

output "ipv4_pool" {
  # dont output entire object only needed attributes
  value = {
    id = aws_vpc_ipam_pool.this_ipv4.id
  }
}


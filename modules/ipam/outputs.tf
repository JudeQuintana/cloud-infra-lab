output "id" {
  value = aws_vpc_ipam.this.id
}

output "ipv4_pool" {
  # dont output entire object only needed attributes
  value = {
    id = aws_vpc_ipam_pool.this_ipv4.id
    # not expecting provision_cidrs to be consumed by a tiered vpc (only the ipv4_pool.id is needed) by populating the provision cidrs in the ipv4_pool object to force specific DAG behavior
    # this is a shim/hack forcing the DAG to finish provisioning the module cidrs before the pool id is consumed without needing the consuming vpc to have a direct/explicit dependency on the ipam module aws_vpc_ipam_pool_cidr.this_ipv4 (not possible).
    # otherwise the consumer vpc of the pool id will try to use the ipam cidr before the expected cidr is finished being provisioned (race condition)
    provision_cidrs = [for this in aws_vpc_ipam_pool_cidr.this_ipv4 : this.cidr]
  }
}


output "primary_identifier" {
  value = local.primary_identifier
}

output "primary_address" {
  value = aws_db_instance.this_primary.address
}

output "read_replica_address" {
  value = aws_db_instance.this_read_replica.address
}

# not same as family for db_parameter group
# for use with rds_proxy default will be "MYSQL"
output "engine_family" {
  value = strcontains(var.rds.engine, "mysql") ? upper(var.rds.engine) : null
}

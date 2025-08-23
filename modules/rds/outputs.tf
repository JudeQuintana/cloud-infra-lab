output "primary_identifier" {
  value = local.primary_identifier
}

output "primary_address" {
  value = aws_db_instance.this_primary.address
}

output "read_replica_address" {
  value = aws_db_instance.this_read_replica.address
}

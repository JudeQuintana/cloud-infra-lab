# valid mysql db admin pass
resource "random_password" "rds_password" {
  length           = 32
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%^&*()-_=+[]{}:;,.?"
}

locals {
  ## cant put all rds info into an object due to some of the self referenital naming when using format in an object
  ## therefore keeping them separated into separate local vars
  #rds_primary_identifier = format(local.name_fmt, local.name, "primary")
  #rds_replica_identifier = format(local.name_fmt, local.name, "replica")
  ##rds_identifier              = format(local.name_fmt, var.env_prefix, local.rds_primary_name)
  ##rds_replica_identifier      = format(local.name_fmt, var.env_prefix, local.rds_replica_name)
  #rds_final_snapshot_name     = format(local.name_fmt, local.rds_identifier, "final-snapshot")
  #rds_db_parameter_group_name = format(local.name_fmt, local.rds_identifier, "replication")
  #rds_engine                  = "mysql"
  #rds_engine_version          = "8.4.5"
  #rds_family                  = "mysql8.4"
  #rds_instance_class          = "db.t3.micro"
  #rds_storage_encrypted       = true
  #rds_multi_az                = true
  rds_connection = {
    db_name  = "appdb"
    username = "admin"
    password = random_password.rds_password.result
    port     = 3306
    timeout  = 3
  }
}
# MYSQL RDS primary and read replica DB instances
module "rds" {
  source = "./modules/rds"

  env_prefix = var.env_prefix
  rds = {
    name               = "app"
    connection         = local.rds_connection
    security_group_ids = [aws_security_group.rds_sg.id]
    subnet_ids = [
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db1"),
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db2")
    ]
  }
}

locals {
  rds_proxy_endpoint_or_db_instance_address = var.enable_rds_proxy ? lookup(module.rds_proxy, var.enable_rds_proxy).default_endpoint : module.rds.primary_address
  # RDS proxy doesnt support read only endpoints for DB instances (cheap HA), only RDS clusters (more expensive)
  # therefore read replica instance access bypasses the RDS proxy
  rds_connection_with_hosts = merge(
    local.rds_connection,
    {
      host              = local.rds_proxy_endpoint_or_db_instance_address
      read_replica_host = module.rds.read_replica_address
    }
  )
}


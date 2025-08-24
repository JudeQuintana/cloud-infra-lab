# valid mysql db admin pass
resource "random_password" "rds_password" {
  length           = 32
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%^&*()-_=+[]{}:;,.?"
}

locals {
  rds_connection = {
    db_name  = "appdb"
    username = "admin"
    password = random_password.rds_password.result
    port     = 3306
    timeout  = 3
  }
}

# Multi-AZ MYSQL RDS primary and read replica DB instances by default
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
  rds_proxy_endpoint_or_primary_db_instance_address = var.enable_rds_proxy ? lookup(module.rds_proxy, var.enable_rds_proxy).default_endpoint : module.rds.primary_address
  # RDS proxy doesnt support read only endpoints for DB instances (cheap HA), only RDS clusters (more expensive)
  # therefore read replica instance access bypasses the RDS proxy
  rds_connection_with_hosts = merge(
    local.rds_connection,
    {
      primary_host      = local.rds_proxy_endpoint_or_primary_db_instance_address
      read_replica_host = module.rds.read_replica_address
    }
  )
}


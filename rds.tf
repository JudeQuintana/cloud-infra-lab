# valid mysql db admin pass
# dont use $ for issues with variable expansion in the shell on the ec2 host
# and # might comment out the line since incase not wrapping env vars with doubel quotes
# or other potntial problematic characters like ; / "
resource "random_password" "rds_password" {
  length           = 32
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!%^&*()-_=+[]{};,.?"
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

# Only supports RDS engines that have the mysql string in the name, hasnt been tested with other DBs
# Multi-AZ RDS primary and read replica DB instances by default
module "rds" {
  source = "./modules/rds"

  env_prefix = var.env_prefix
  rds = {
    name                      = "app"
    engine                    = "mysql"
    engine_version            = "8.4.5"
    db_parameter_group_family = "mysql8.4"
    instance_class            = "db.t3.micro"
    db_parameters = [{
      # (Default) safest—each event contains full before/after row image for replication to read replica when using mysql rds engine
      apply_method = "immediate"
      name         = "binlog_row_image"
      value        = "FULL"
    }]
    connection         = local.rds_connection
    security_group_ids = [aws_security_group.rds.id]
    subnet_ids = [
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db1"),
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db2")
    ]
  }
}

locals {
  primary_host_address = var.enable_rds_proxy ? lookup(module.rds_proxy, var.enable_rds_proxy).default_endpoint : module.rds.primary_address
  # RDS proxy doesnt support read only endpoints for DB instances (cheap HA), only RDS clusters (more expensive)
  # therefore read replica instance access bypasses the RDS proxy
  rds_connection_with_hosts = merge(
    local.rds_connection,
    {
      primary_host      = local.primary_host_address
      read_replica_host = module.rds.read_replica_address
    }
  )
}


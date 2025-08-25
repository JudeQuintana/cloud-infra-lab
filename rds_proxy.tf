locals {
  # use this style of map in a resource for_each when count = 1 behavior is needed
  rds_proxy = { for this in [var.enable_rds_proxy] : this => this if var.enable_rds_proxy }
}

# RDS Proxy is MYSQL for DB insteance by default
module "rds_proxy" {
  source = "./modules/rds_proxy"

  for_each = local.rds_proxy

  env_prefix = var.env_prefix
  rds_proxy = {
    name                  = "app"
    rds                   = module.rds
    secretsmanager_secret = aws_secretsmanager_secret.rds
    security_group_ids    = [aws_security_group.rds_proxy_sg.id]
    subnet_ids = [
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db1"),
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db2")
    ]
  }
}


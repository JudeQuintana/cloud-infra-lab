locals {
  # use this style of map in a resource for_each when count = 1 behavior is needed
  rds_proxy = { for this in [var.rds_proxy] : this => this if var.rds_proxy }
}

module "rds_proxy" {
  source = "./modules/rds_proxy"

  for_each = local.rds_proxy

  env_prefix = var.env_prefix
  rds_proxy = {
    primary_db_instance_identifier = aws_db_instance.primary.identifier
    secretsmanager_secret_arn      = aws_secretsmanager_secret.rds.arn
    vpc_security_group_ids         = [aws_security_group.rds_proxy_sg.id]
    vpc_subnet_ids = [
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db1"),
      lookup(local.app_vpc.isolated_subnet_name_to_subnet_id, "db2")
    ]
  }
}


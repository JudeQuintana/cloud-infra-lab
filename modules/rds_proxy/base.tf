# Pull region data from provider
data "aws_region" "this" {}

locals {
  region           = data.aws_region.this.name
  upper_env_prefix = upper(var.env_prefix)
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)

}

### RDS Proxy
locals {
  rds_proxy_name = format("%s-%s", var.env_prefix, "mysql-rds-proxy")
}

# the default target role is READ_WRITE for the proxy endpoint
resource "aws_db_proxy" "this" {
  name                   = local.rds_proxy_name
  engine_family          = var.rds_proxy.engine_family
  role_arn               = aws_iam_role.this.arn
  vpc_security_group_ids = var.rds_proxy.vpc_security_group_ids
  vpc_subnet_ids         = var.rds_proxy.vpc_subnet_ids
  tags                   = local.default_tags # merge name?

  auth {
    auth_scheme = var.rds_proxy.auth_scheme
    secret_arn  = var.rds_proxy.secretsmanager_secret.arn
    iam_auth    = var.rds_proxy.iam_auth
  }

  require_tls         = var.rds_proxy.require_tls
  idle_client_timeout = var.rds_proxy.idle_client_timeout
  debug_logging       = var.rds_proxy.debug_logging
}

resource "aws_db_proxy_default_target_group" "this_default" {
  db_proxy_name = aws_db_proxy.this.name

  connection_pool_config {
    max_connections_percent      = var.rds_proxy.default_target_group_connection_pool_config.max_connections_percent
    max_idle_connections_percent = var.rds_proxy.default_target_group_connection_pool_config.max_idle_connections_percent
    connection_borrow_timeout    = var.rds_proxy.default_target_group_connection_pool_config.connection_borrow_timeout
    session_pinning_filters      = var.rds_proxy.default_target_group_connection_pool_config.session_pinning_filters
  }
}

resource "terraform_data" "this_wait_for_rds_availability" {
  provisioner "local-exec" {
    command = format(
      "aws rds wait db-instance-available --db-instance-identifier %s --region %s",
      var.rds_proxy.primary_db_instance.identifier,
      local.region
    )
  }
}

resource "aws_db_proxy_target" "this_writer" {
  db_proxy_name          = aws_db_proxy.this.name
  target_group_name      = aws_db_proxy_default_target_group.this_default.name
  db_instance_identifier = var.rds_proxy.primary_db_instance.identifier

  # Need this to wait until rds instance to have available hosts to bypass error on first apply, subsequent runs will be idempotent
  # - InvalidDBInstanceState: DB Instance 'test-app-mysql' is in unsupported state - instance does not have any host
  depends_on = [
    terraform_data.this_wait_for_rds_availability
  ]
}


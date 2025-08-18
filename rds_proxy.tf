# IAM required for rds proxy accessing secrets and assume role
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

# RDS Proxy needs to read the secret value and (best practice) describe the secret.
data "aws_iam_policy_document" "rds_proxy_secrets_read_only" {
  statement {
    sid = "AllowReadRDSSecrets"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [aws_secretsmanager_secret.rds.arn]
  }
}

resource "aws_iam_policy" "rds_proxy_secrets_read_only" {
  name   = format("%s-%s", var.env_prefix, "rds-proxy-secrets-readonly")
  policy = data.aws_iam_policy_document.rds_proxy_secrets_read_only.json
}

resource "aws_iam_role" "rds_proxy" {
  name               = format("%s-%s", var.env_prefix, "rds-proxy-role")
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "rds_proxy_secrets_access" {
  role       = aws_iam_role.rds_proxy.name
  policy_arn = aws_iam_policy.rds_proxy_secrets_read_only.arn
}

## RDS Proxy
# the default target role is READ_WRITE for the proxy endpoint
resource "aws_db_proxy" "rds_proxy" {
  name                   = format("%s-%s", var.env_prefix, "mysql-rds-proxy")
  engine_family          = "MYSQL"
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.rds_proxy_sg.id]
  vpc_subnet_ids = [
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db1"],
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db2"]
  ]

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.rds.arn
    iam_auth    = "DISABLED"
  }

  require_tls = true
  # This helps recycle pinned client connections faster without being too aggressive insead of 1800 default
  idle_client_timeout = 900
  debug_logging       = false
}

resource "aws_db_proxy_default_target_group" "rds_proxy_tg" {
  db_proxy_name = aws_db_proxy.rds_proxy.name

  # Steady web/ECS/EKS app – balanced reuse, moderate queueing
  # `session_pinning_filters` can reduce session pinning from SET statements
  # and improve multiplexing—use only if safe for your app’s session semantics.
  # tune to your needs
  connection_pool_config {
    max_connections_percent      = 85
    max_idle_connections_percent = 40
    connection_borrow_timeout    = 10
    session_pinning_filters      = ["EXCLUDE_VARIABLE_SETS"] # MYSQL Engine specific
  }
}

resource "terraform_data" "wait_for_rds" {
  provisioner "local-exec" {
    command = format(
      "aws rds wait db-instance-available --db-instance-identifier %s --region %s",
      aws_db_instance.mysql.identifier,
      local.region
    )
  }
}

resource "aws_db_proxy_target" "writer" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.rds_proxy_tg.name
  db_instance_identifier = aws_db_instance.mysql.identifier

  # Need this to wait until rds instance to have available hosts to bypass error on first apply, subsequent runs will be idempotent
  # - InvalidDBInstanceState: DB Instance 'test-app-mysql' is in unsupported state - instance does not have any host
  depends_on = [
    terraform_data.wait_for_rds
  ]
}

locals {
  rds_connection_with_hosts = merge(
    local.rds_connection,
    {
      host = aws_db_proxy.rds_proxy.endpoint
      # RDS proxy doesnt support read only endpoints for DB instances (cheap), only RDS clusters (more expensive)
      # therefore read replica instance access bypasses the RDS proxy
      read_replica_host = aws_db_instance.read_replica.address
    }
  )
}


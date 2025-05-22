# IAM
data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "rds_proxy" {
  name               = "rds-proxy-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "rds_proxy_secrets_access" {
  role       = aws_iam_role.rds_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}


resource "aws_db_proxy" "rds_proxy" {
  name                   = "my-db-proxy"
  engine_family          = "MYSQL"
  role_arn               = aws_iam_role.rds_proxy.arn
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  vpc_subnet_ids = [
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db1"],
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db2"]
  ]

  auth {
    auth_scheme = "SECRETS"
    secret_arn  = aws_secretsmanager_secret.rds.arn
    iam_auth    = "DISABLED"
  }

  require_tls         = true
  idle_client_timeout = 1800
  debug_logging       = false
}

resource "aws_db_proxy_default_target_group" "rds_proxy_tg" {
  db_proxy_name = aws_db_proxy.rds_proxy.name
}

resource "aws_db_proxy_target" "rds_instance" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.rds_proxy_tg.name
  db_instance_identifier = aws_db_instance.mysql.identifier
}

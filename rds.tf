# valid db admin pass
resource "random_password" "rds_password" {
  length           = 32
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%^&*()-_=+[]{}:;,.?"
}

resource "aws_kms_key" "rds" {
  description             = "KMS CMK for MySQL RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_kms_alias" "rds" {
  name          = format("alias/%s-%s", var.env_prefix, "rds-mysql")
  target_key_id = aws_kms_key.rds.key_id
}

resource "aws_db_subnet_group" "mysql" {
  name = format("%s-%s", var.env_prefix, "mysql-subnet-group")
  subnet_ids = [
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db1"],
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db2"]
  ]

  tags = {
    Name = format("%s-%s", var.env_prefix, "mysql-subnet-group")
  }
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

resource "aws_db_instance" "mysql" {
  identifier                = format("%s-%s", var.env_prefix, "app-mysql")
  engine                    = "mysql"
  engine_version            = "8.0"
  instance_class            = "db.t3.micro"
  allocated_storage         = 20
  storage_type              = "gp2"
  multi_az                  = true
  deletion_protection       = true
  vpc_security_group_ids    = [aws_security_group.mysql_sg.id]
  db_subnet_group_name      = aws_db_subnet_group.mysql.name
  storage_encrypted         = true
  kms_key_id                = aws_kms_key.rds.arn
  final_snapshot_identifier = format("%s-%s", var.env_prefix, "app-mysql-final-snapshot")
  db_name                   = local.rds_connection.db_name
  username                  = local.rds_connection.username
  password                  = local.rds_connection.password
  port                      = local.rds_connection.port

  tags = {
    Name = format("%s-%s", var.env_prefix, "app-mysql")
  }
}

# rds proxy
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
  name               = format("%s-%s", var.env_prefix, "rds-proxy-role")
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "rds_proxy_secrets_access" {
  role       = aws_iam_role.rds_proxy.name
  policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
}


resource "aws_db_proxy" "rds_proxy" {
  name                   = format("%s-%s", var.env_prefix, "mysql-rds-proxy")
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

# need this to bypass error on apply:
# InvalidDBInstanceState: DB Instance 'test-app-mysql' is in unsupported state - instance does not have any host
resource "terraform_data" "wait_for_rds" {
  provisioner "local-exec" {
    command = format("aws rds wait db-instance-available --db-instance-identifier %s --region %s", aws_db_instance.mysql.identifier, local.region)
  }

  depends_on = [aws_db_instance.mysql]
}

resource "aws_db_proxy_target" "rds_proxy_target" {
  db_proxy_name          = aws_db_proxy.rds_proxy.name
  target_group_name      = aws_db_proxy_default_target_group.rds_proxy_tg.name
  db_instance_identifier = aws_db_instance.mysql.identifier

  depends_on = [
    terraform_data.wait_for_rds
  ]
}

locals {
  rds_connection_with_host = merge(
    local.rds_connection,
    { host = aws_db_proxy.rds_proxy.endpoint }
  )
}


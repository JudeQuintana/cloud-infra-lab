# use secrets manager to access admin creds elsewhere
resource "aws_secretsmanager_secret" "rds" {
  name = "rds/mysql/app"
}

resource "aws_secretsmanager_secret_version" "rds" {
  secret_id     = aws_secretsmanager_secret.rds.id
  secret_string = jsonencode(local.rds_connection_with_host)
}


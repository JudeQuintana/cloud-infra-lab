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

  rds_identifier          = format("%s-%s", var.env_prefix, "app-mysql")
  rds_final_snapshot_name = format("%s-%s", local.rds_identifier, "final-snapshot")
}

resource "aws_db_instance" "mysql" {
  identifier                = local.rds_identifier
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
  final_snapshot_identifier = local.rds_final_snapshot_name
  db_name                   = local.rds_connection.db_name
  username                  = local.rds_connection.username
  password                  = local.rds_connection.password
  port                      = local.rds_connection.port

  tags = {
    Name = format("%s-%s", var.env_prefix, "app-mysql")
  }
}


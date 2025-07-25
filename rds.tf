resource "aws_kms_key" "rds" {
  description             = "KMS CMK for MySQL RDS encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

locals {
  kms_alias_name = format("alias/%s-%s", var.env_prefix, "rds-mysql")
}

resource "aws_kms_alias" "rds" {
  name          = local.kms_alias_name
  target_key_id = aws_kms_key.rds.key_id
}

locals {
  db_subnet_group_name = format(local.name_fmt, var.env_prefix, "mysql-subnet-group")
}

resource "aws_db_subnet_group" "mysql" {
  name = local.db_subnet_group_name
  subnet_ids = [
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db1"],
    lookup(module.vpcs, local.vpc_names.app).isolated_subnet_name_to_subnet_id["db2"]
  ]

  tags = {
    Name = local.db_subnet_group_name
  }
}

# valid mysql db admin pass
resource "random_password" "rds_password" {
  length           = 32
  override_special = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!#$%^&*()-_=+[]{}:;,.?"
}

locals {
  # cant put all rds info into an object due to some of the self referenital naming when using format in an object
  # therefore keeping them separated into separate local vars
  rds_name                    = "app-mysql"
  rds_engine                  = "mysql"
  rds_engine_version          = "8.4.5"
  rds_identifier              = format(local.name_fmt, var.env_prefix, local.rds_name)
  rds_final_snapshot_name     = format(local.name_fmt, local.rds_identifier, "final-snapshot")
  rds_replica_identifier      = format(local.name_fmt, local.rds_identifier, "replica")
  rds_db_parameter_group_name = format(local.name_fmt, local.rds_identifier, "replication")
  rds_family                  = "mysql8.4"
  rds_instance_class          = "db.t3.micro"
  rds_storage_encrypted       = true
  rds_multi_az                = true
  rds_connection = {
    db_name  = "appdb"
    username = "admin"
    password = random_password.rds_password.result
    port     = 3306
    timeout  = 3
  }
}

# binlog format parameter has been deprecated for rds replication for mysql engine 8.0.34+ and 8.4.0
# MySQL plans to remove the parameter and only support row-based replication by default.
# Below is an empty db parameter group as a place holder for db parameters.
# if mysql engine is 8.0.33 and lower then a binlog_format would be required for mysql replication
# for example:
# parameter {
#   name  = "binlog_format"
#   value = "ROW"
# }
#
# tune the db parameter group to your db needs
resource "aws_db_parameter_group" "rds_replication" {
  name   = local.rds_db_parameter_group_name
  family = local.rds_family

  parameter {
    # (Default) safest—each event contains full before/after row image.
    name         = "binlog_row_image"
    value        = "FULL"
    apply_method = "immediate"
  }

  tags = {
    Name = local.rds_db_parameter_group_name
  }
}

# if backup_retention_period is not set at init for replication then
# apply_immediately = true must be set to continue building the read replica
# otherwise there will be non-idempotent drift and wont TF update the primary msyql resource (until scheduled maintenance occurs)
# and the read replica will fail
resource "aws_db_instance" "mysql" {
  identifier                = local.rds_identifier
  engine                    = local.rds_engine
  engine_version            = local.rds_engine_version
  instance_class            = local.rds_instance_class
  allocated_storage         = 20
  storage_type              = "gp2"
  multi_az                  = local.rds_multi_az
  deletion_protection       = true
  vpc_security_group_ids    = [aws_security_group.mysql_sg.id]
  backup_retention_period   = 7     # required greater than 0 if read replica exists
  apply_immediately         = false # sometimes you'll need to set apply_immediately to true on the main DB when changing values like increasing backup_retention_period from 0 to 7 (etc) if they were not applied during init. Then set back to false after apply. Use sparingly.
  parameter_group_name      = aws_db_parameter_group.rds_replication.name
  db_subnet_group_name      = aws_db_subnet_group.mysql.name
  storage_encrypted         = local.rds_storage_encrypted
  kms_key_id                = aws_kms_key.rds.arn
  final_snapshot_identifier = local.rds_final_snapshot_name
  db_name                   = local.rds_connection.db_name
  username                  = local.rds_connection.username
  password                  = local.rds_connection.password
  port                      = local.rds_connection.port

  tags = {
    Name = local.rds_identifier
  }
}

locals {
  rds_connection_with_host = merge(
    local.rds_connection,
    { host = aws_db_instance.mysql.address }
  )
}

resource "aws_db_instance" "read_replica" {
  identifier             = local.rds_replica_identifier
  replicate_source_db    = aws_db_instance.mysql.arn
  instance_class         = local.rds_instance_class
  vpc_security_group_ids = [aws_security_group.mysql_sg.id]
  db_subnet_group_name   = aws_db_instance.mysql.db_subnet_group_name
  multi_az               = local.rds_multi_az
  storage_encrypted      = local.rds_storage_encrypted
  skip_final_snapshot    = true # required for read replica

  tags = {
    Name = local.rds_replica_identifier
  }
}

locals {
  rds_connection_with_read_replica_host = merge(
    local.rds_connection_with_host,
    { read_replica_host = aws_db_instance.read_replica.address }
  )
}


locals {
  name_fmt                = "%s-%s"
  name                    = format(local.name_fmt, var.env_prefix, var.rds.name)
  primary_identifier      = format(local.name_fmt, local.name, "primary")
  read_replica_identifier = format(local.name_fmt, local.name, "replica")
  final_snapshot_name     = format(local.name_fmt, local.name, "final-snapshot")
  storage_encrypted       = true
  multi_az                = true
  #rds_identifier          = format(local.name_fmt, var.env_prefix, local.rds_primary_name)
  #rds_replica_identifier  = format(local.name_fmt, var.env_prefix, local.rds_replica_name)
  #db_subnet_group_name    = format(local.name_fmt, local.name, "subnet-group")
  #db_parameter_group_name = format(local.name_fmt, local.name, "db-paramater-group")
}

resource "aws_db_subnet_group" "this" {
  name       = local.name
  subnet_ids = var.rds.subnet_ids

  tags = {
    Name = local.name
  }
}

locals {
  parameter_name_to_parameter = { for this in var.rds.db_parameters : this.name => this }
}

resource "aws_db_parameter_group" "this" {
  name   = local.name
  family = var.rds.family

  dynamic "parameter" {
    for_each = local.parameter_name_to_parameter

    content {
      apply_method = parameter.value.apply_method
      name         = parameter.value.name
      value        = parameter.value.value
    }
  }

  tags = {
    Name = local.name
  }
}

resource "aws_db_instance" "this_primary" {
  identifier                = local.primary_identifier
  engine                    = var.rds.engine
  engine_version            = var.rds.engine_version
  instance_class            = var.rds.instance_class
  allocated_storage         = var.rds.allocated_storage
  storage_type              = var.rds.storage_type
  multi_az                  = local.multi_az
  deletion_protection       = var.rds.deletion_protection
  vpc_security_group_ids    = var.rds.security_group_ids
  db_subnet_group_name      = aws_db_subnet_group.this.name
  backup_retention_period   = var.rds.backup_retention_period
  apply_immediately         = var.rds.apply_immediately
  parameter_group_name      = aws_db_parameter_group.this.name
  storage_encrypted         = local.storage_encrypted
  kms_key_id                = aws_kms_key.this.arn
  final_snapshot_identifier = local.final_snapshot_name
  db_name                   = var.rds.connection.db_name
  username                  = var.rds.connection.username
  password                  = var.rds.connection.password
  port                      = var.rds.connection.port

  tags = {
    Name = local.primary_identifier
  }
}

resource "aws_db_instance" "this_read_replica" {
  identifier             = local.read_replica_identifier
  replicate_source_db    = aws_db_instance.this_primary.arn
  instance_class         = var.rds.instance_class
  vpc_security_group_ids = var.rds.security_group_ids
  db_subnet_group_name   = aws_db_subnet_group.this.name
  multi_az               = local.multi_az
  storage_encrypted      = local.storage_encrypted
  skip_final_snapshot    = true # required for read replica

  tags = {
    Name = local.read_replica_identifier
  }
}


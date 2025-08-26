variable "env_prefix" {
  description = "prod, stage, test"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}

variable "rds" {
  description = "RDS configuration (Multi-AZ DB Instance with read replica and MYSQL specific for Cloud Infra Lab)"
  type = object({
    name = string
    connection = object({
      db_name  = string
      username = string
      password = string
      port     = optional(number, 3306)
    })
    security_group_ids        = list(string)
    subnet_ids                = list(string)
    engine                    = string
    engine_version            = string
    db_parameter_group_family = string
    instance_class            = string
    deletion_protection       = optional(bool, true)
    # required greater than 0 when read replica exists
    backup_retention_period = optional(number, 7)
    # sometimes you'll need to set apply_immediately to true on the primary DB when changing values like increasing backup_retention_period from 0 to 7 (etc) if they were not applied during init. Then set back to false after apply. Use sparingly.
    apply_immediately          = optional(bool, false)
    allocated_storage          = optional(number, 20)
    storage_type               = optional(string, "gp2")
    auto_minor_version_upgrade = optional(bool, true)
    # binlog format parameter has been deprecated for rds replication for mysql engine 8.0.34+ and 8.4.0
    # MySQL plans to remove the parameter and only support row-based replication by default.
    # if mysql engine is 8.0.33 and lower then a binlog_format would be required for mysql replication
    # for example:
    # [{
    #   name  = "binlog_format"
    #   value = "ROW"
    # }]
    #
    # tune the db parameter group to your db needs
    db_parameters = optional(list(object({
      apply_method = string
      name         = string
      value        = string
    })), [])
  })

  validation {
    condition     = var.rds.backup_retention_period > 0
    error_message = "The Primary DB Instance backup_retention_period must be greater than zero when read replicas exist."
  }

  validation {
    condition     = strcontains(var.rds.engine, "mysql") ? contains(var.rds.db_parameters, { apply_method = "immediate", name = "binlog_row_image", value = "FULL" }) : true
    error_message = "When read replicas exist, if the RDS engine is contains \"msyql\" then the DB Parameters list must include a parameter object with { apply_method = \"immediate name\" = \"binlog_row_image\" , value = \"FULL\" }"
  }

  validation {
    condition     = strcontains(var.rds.engine, "mysql")
    error_message = " Only supports RDS engines that have the mysql string in the name, hasnt been tested with other DBs"
  }
}


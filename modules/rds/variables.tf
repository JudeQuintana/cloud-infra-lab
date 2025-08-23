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
    security_group_ids  = list(string)
    subnet_ids          = list(string)
    engine              = optional(string, "mysql")
    engine_version      = optional(string, "8.4.5")
    family              = optional(string, "mysql8.4")
    instance_class      = optional(string, "db.t3.micro")
    deletion_protection = optional(bool, true)
    # required greater than 0 if read replica exists
    # add to variable validation must be more than 0
    backup_retention_period = optional(number, 7)
    # sometimes you'll need to set apply_immediately to true on the primary DB when changing values like increasing backup_retention_period from 0 to 7 (etc) if they were not applied during init. Then set back to false after apply. Use sparingly.
    apply_immediately = optional(bool, false)
    allocated_storage = optional(number, 20)
    storage_type      = optional(string, "gp2")
    # add to variable validation must have this for replication
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
      # (Default) safest—each event contains full before/after row image.
      apply_method = optional(string, "immediate")
      name         = optional(string, "binlog_row_image")
      value        = optional(string, "FULL")
    })), [])
  })
}


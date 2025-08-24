
This is an RDS module that is specific to Multi-AZ MYSQL RDS DB Instance with read replica for Cloud Infra Lab
Could probably use more variable validation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.4 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.61 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=5.61 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_db_instance.this_primary](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_instance.this_read_replica](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_instance) | resource |
| [aws_db_parameter_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_parameter_group) | resource |
| [aws_db_subnet_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_subnet_group) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env_prefix"></a> [env\_prefix](#input\_env\_prefix) | prod, stage, test | `string` | n/a | yes |
| <a name="input_rds"></a> [rds](#input\_rds) | RDS configuration (Multi-AZ DB Instance with read replica and MYSQL specific for Cloud Infra Lab) | <pre>object({<br/>    name = string<br/>    connection = object({<br/>      db_name  = string<br/>      username = string<br/>      password = string<br/>      port     = optional(number, 3306)<br/>    })<br/>    security_group_ids  = list(string)<br/>    subnet_ids          = list(string)<br/>    engine              = optional(string, "mysql")<br/>    engine_version      = optional(string, "8.4.5")<br/>    family              = optional(string, "mysql8.4")<br/>    instance_class      = optional(string, "db.t3.micro")<br/>    deletion_protection = optional(bool, true)<br/>    # required greater than 0 if read replica exists<br/>    # add to variable validation must be more than 0<br/>    backup_retention_period = optional(number, 7)<br/>    # sometimes you'll need to set apply_immediately to true on the primary DB when changing values like increasing backup_retention_period from 0 to 7 (etc) if they were not applied during init. Then set back to false after apply. Use sparingly.<br/>    apply_immediately = optional(bool, false)<br/>    allocated_storage = optional(number, 20)<br/>    storage_type      = optional(string, "gp2")<br/>    # add to variable validation must have this for replication<br/>    # binlog format parameter has been deprecated for rds replication for mysql engine 8.0.34+ and 8.4.0<br/>    # MySQL plans to remove the parameter and only support row-based replication by default.<br/>    # if mysql engine is 8.0.33 and lower then a binlog_format would be required for mysql replication<br/>    # for example:<br/>    # [{<br/>    #   name  = "binlog_format"<br/>    #   value = "ROW"<br/>    # }]<br/>    #<br/>    # tune the db parameter group to your db needs<br/>    db_parameters = optional(list(object({<br/>      # (Default) safest—each event contains full before/after row image.<br/>      apply_method = optional(string, "immediate")<br/>      name         = optional(string, "binlog_row_image")<br/>      value        = optional(string, "FULL")<br/>    })), [])<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_primary_address"></a> [primary\_address](#output\_primary\_address) | n/a |
| <a name="output_primary_identifier"></a> [primary\_identifier](#output\_primary\_identifier) | n/a |
| <a name="output_read_replica_address"></a> [read\_replica\_address](#output\_read\_replica\_address) | n/a |

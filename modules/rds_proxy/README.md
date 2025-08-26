
This is an RDS Proxy that is specific to RDS DB Instances and MYSQL configuration for Cloud Infra Lab
No RDS Cluster support at this time
Could probably use more variable validation

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >=1.5 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >=5.61 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >=5.61 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_db_proxy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_proxy) | resource |
| [aws_db_proxy_default_target_group.this_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_proxy_default_target_group) | resource |
| [aws_db_proxy_target.this_writer](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/db_proxy_target) | resource |
| [aws_iam_policy.this_secrets_read_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.this_secrets_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [terraform_data.this_wait_for_rds_availability](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_iam_policy_document.this_assume_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.this_secrets_read_only](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_env_prefix"></a> [env\_prefix](#input\_env\_prefix) | prod, stage, test | `string` | n/a | yes |
| <a name="input_rds_proxy"></a> [rds\_proxy](#input\_rds\_proxy) | RDS Proxy configuration (RDS DB Instance for Cloud Infra Lab) | <pre>object({<br/>    name = string<br/>    rds = object({<br/>      engine_family      = string<br/>      primary_identifier = string<br/>      primary_address    = string<br/>    })<br/>    secretsmanager_secret = object({<br/>      arn = string<br/>    })<br/>    security_group_ids = list(string)<br/>    subnet_ids         = list(string)<br/>    require_tls        = optional(bool, true)<br/>    # This helps recycle pinned client connections faster without being too aggressive insead of 1800 default<br/>    idle_client_timeout = optional(number, 900)<br/>    debug_logging       = optional(bool, false)<br/>    connection_pool_config = object({<br/>      max_connections_percent      = number<br/>      max_idle_connections_percent = number<br/>      connection_borrow_timeout    = number<br/>      session_pinning_filters      = optional(list(string))<br/>    })<br/>  })</pre> | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_default_endpoint"></a> [default\_endpoint](#output\_default\_endpoint) | n/a |
| <a name="output_id"></a> [id](#output\_id) | n/a |

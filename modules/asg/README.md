
This is an ASG module that is specific to Cloud Infra Lab
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

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_policy.this_scale_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_autoscaling_policy.this_scale_out](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_policy) | resource |
| [aws_cloudwatch_metric_alarm.this_cpu_high](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_cloudwatch_metric_alarm.this_cpu_low](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_metric_alarm) | resource |
| [aws_kms_alias.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key_policy) | resource |
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_caller_identity.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_asg"></a> [asg](#input\_asg) | ASG configuration specific to Cloud Infra Lab | <pre>object({<br/>    name = string<br/>    ami = object({<br/>      id = string<br/>    })<br/>    user_data          = string<br/>    security_group_ids = list(string)<br/>    subnet_ids         = list(string)<br/>    alb = object({<br/>      target_group_arn = string<br/>    })<br/>    min_size = number<br/>    max_size = number<br/>    # will launch with initial desired_capacity value<br/>    # but any updates will be ignored so that the sale in and scale out alarms takeover<br/>    # uncomment lifecyle ignore changes for desired_capacity in the asg.<br/>    desired_capacity = number<br/>    instance_type    = string<br/>    # optional key pair name for use when troubleshooting instances via ssh from a bastion host<br/>    key_name = optional(string)<br/>    # start a launch-before-terminate asg instance refresh using the latest launch template automatically after the launch template is modified<br/>    instance_refresh          = optional(bool, true)<br/>    health_check_grace_period = optional(number, 120)<br/>    # root volume<br/>    ebs = optional(object({<br/>      root_volume_type = optional(string, "gp3")<br/>      root_volume_size = optional(number, 8)<br/>    }), {})<br/>    cloudwatch_alarms = optional(object({<br/>      cpu_high = optional(object({<br/>        evaluation_periods = optional(number, 2)<br/>        period             = optional(number, 60)<br/>        threshold          = optional(number, 70)<br/>        description        = optional(string, "Scale out if CPU > 70% for 2 minutes")<br/>      }), {})<br/>      cpu_low = optional(object({<br/>        evaluation_periods = optional(number, 2)<br/>        period             = optional(number, 60)<br/>        threshold          = optional(number, 30)<br/>        description        = optional(string, "Scale in if CPU < 30% for 2 minutes")<br/>      }), {})<br/>    }), {})<br/>  })</pre> | n/a | yes |
| <a name="input_env_prefix"></a> [env\_prefix](#input\_env\_prefix) | prod, stage, test | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | n/a |
| <a name="output_instance_refresh"></a> [instance\_refresh](#output\_instance\_refresh) | n/a |

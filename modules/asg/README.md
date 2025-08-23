
This is an ASG module that is specific to Cloud Infra Lab
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
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

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
| [aws_launch_template.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [terraform_data.this_instance_refresher](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [aws_region.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_asg"></a> [asg](#input\_asg) | ASG configuration specific to Cloud Infra Lab | <pre>object({<br/>    name = string<br/>    ami = object({<br/>      id = string<br/>    })<br/>    user_data          = string<br/>    security_group_ids = list(string)<br/>    subnet_ids         = list(string)<br/>    alb = object({<br/>      target_group_arn = string<br/>    })<br/>    instance_refresh = bool<br/>    min_size         = number<br/>    max_size         = number<br/>    # will launch with initial desired_capacity value<br/>    # but any updates will be ignored so that the sale in and scale out alarms takeover<br/>    # uncomment lifecyle ignore changes for desired_capacity in the asg.<br/>    desired_capacity          = number<br/>    health_check_grace_period = optional(number, 300)<br/>    instance_type             = optional(string, "t2.micro")<br/>    # This tells the asg to keep 100% of your desired capacity healthy before it starts terminating old instances,<br/>    # and allows it to exceed capacity by up to 50% during replacements.<br/>    # This coincides with terraform_data.asg_instance_refresher to get 'launch before terminate' behavior.<br/>    instance_maintenance_policy = optional(object({<br/>      min_healthy_percentage = optional(number, 100)<br/>      max_healthy_percentage = optional(number, 150)<br/>    }), {})<br/>    cloudwatch_alarms = optional(object({<br/>      cpu_low = optional(object({<br/>        evaluation_periods = optional(number, 2)<br/>        period             = optional(number, 60)<br/>        threshold          = optional(number, 30)<br/>        description        = optional(string, "Scale in if CPU < 30% for 2 minutes")<br/>      }), {})<br/>      cpu_high = optional(object({<br/>        evaluation_periods = optional(number, 2)<br/>        period             = optional(number, 60)<br/>        threshold          = optional(number, 70)<br/>        description        = optional(string, "Scale out if CPU > 70% for 2 minutes")<br/>      }), {})<br/>    }), {})<br/>  })</pre> | n/a | yes |
| <a name="input_env_prefix"></a> [env\_prefix](#input\_env\_prefix) | prod, stage, test | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_id"></a> [id](#output\_id) | n/a |


This is an ALB that is specific to Cloud Infra Lab

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
| [aws_acm_certificate.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate) | resource |
| [aws_acm_certificate_validation.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/acm_certificate_validation) | resource |
| [aws_lb.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb) | resource |
| [aws_lb_listener.this_http_to_https_redirect](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_listener.this_https](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_listener) | resource |
| [aws_lb_target_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lb_target_group) | resource |
| [aws_route53_record.this_alb_cname](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |
| [aws_route53_record.this_cert_validation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route53_record) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_alb"></a> [alb](#input\_alb) | ALB configuration specific to Cloud Infra Lab | <pre>object({<br/>    name = string<br/>    zone = object({<br/>      zone_id = string<br/>    })<br/>    domain_name        = string<br/>    security_group_ids = list(string)<br/>    # combine these two somehow<br/>    #vpc_subnet_ids     = list(string)<br/>    #vpc_id             = string<br/>    vpc_with_selected_subnet_ids = object({<br/>      vpc = object({<br/>        id = string<br/>      })<br/>      subnet_ids = list(string)<br/>    })<br/>    target_group_health_check = optional(object({<br/>      path                = optional(string, "/")<br/>      matcher             = optional(string, "200")<br/>      healthy_threshold   = optional(number, 3)<br/>      unhealthy_threshold = optional(number, 3)<br/>      interval            = optional(number, 30)<br/>      timeout             = optional(number, 5)<br/>    }), {})<br/>    https_listener = optional(object({<br/>      ssl_policy = optional(string, "ELBSecurityPolicy-TLS13-1-0-2021-06")<br/>    }), {})<br/>  })</pre> | n/a | yes |
| <a name="input_env_prefix"></a> [env\_prefix](#input\_env\_prefix) | prod, stage, test | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Additional tags | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_target_group_arn"></a> [target\_group\_arn](#output\_target\_group\_arn) | n/a |

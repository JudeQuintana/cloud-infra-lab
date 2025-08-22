# Pull region data from provider
data "aws_region" "this" {}

locals {
  region = data.aws_region.this.name # wont need this if using inline instance refresh instead of cli
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)
  name_fmt = "%s-%s"

  name                         = format(local.name_fmt, var.env_prefix, var.asg.name)
  launch_template_name_prefix  = format("%s-", local.name)
  web_lt_and_asg_instance_name = format(local.name_fmt, local.name, "instance")
}

resource "aws_launch_template" "this" {
  name_prefix            = local.launch_template_name_prefix
  image_id               = var.asg.ami.id
  instance_type          = var.asg.instance_type
  vpc_security_group_ids = var.asg.security_group_ids
  user_data              = var.asg.user_data

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      local.default_tags,
      {
        Name = local.web_lt_and_asg_instance_name
      }
    )
  }
}

locals {
  web_asg_name = format(local.name_fmt, local.name, "asg")
}

resource "aws_autoscaling_group" "this" {
  name                      = local.web_asg_name
  min_size                  = 2
  max_size                  = 8
  desired_capacity          = 2
  vpc_zone_identifier       = var.asg.subnet_ids
  target_group_arns         = [var.asg.alb.target_group_arn]
  health_check_type         = "EC2"
  health_check_grace_period = 300

  launch_template {
    id = aws_launch_template.this.id
    #version = aws_launch_template.this.latest_version
    version = "$Latest"
  }

  # This tells the asg to keep 100% of your desired capacity healthy before it starts terminating old instances,
  # and allows it to exceed capacity by up to 50% during replacements.
  # This coincides with terraform_data.asg_instance_refresher to get 'launch before terminate' behavior.
  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 150
  }

  tag {
    key                 = "Name"
    value               = local.web_lt_and_asg_instance_name
    propagate_at_launch = true
  }

  # will launch with initial desired_capacity value
  # but need to ignore future values to let cloudwatch control scaling out and in which will change the value (comment lifecycle block to take over controlling desired_capactity via TF)
  lifecycle {
    ignore_changes = [desired_capacity]
  }
}


locals {
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)
  name_fmt                     = "%s-%s"
  name                         = format(local.name_fmt, var.env_prefix, var.asg.name)
  launch_template_name_prefix  = format("%s-", local.name)
  web_asg_name                 = format(local.name_fmt, local.name, "asg")
  web_lt_and_asg_instance_name = format(local.name_fmt, local.name, "instance")
  instance_refresh             = { for this in [var.asg.instance_refresh] : this => this if var.asg.instance_refresh }
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

resource "aws_autoscaling_group" "this" {
  name                      = local.web_asg_name
  min_size                  = var.asg.min_size
  max_size                  = var.asg.max_size
  desired_capacity          = var.asg.desired_capacity
  vpc_zone_identifier       = var.asg.subnet_ids
  target_group_arns         = [var.asg.alb.target_group_arn]
  health_check_type         = "EC2"
  health_check_grace_period = var.asg.health_check_grace_period

  launch_template {
    id      = aws_launch_template.this.id
    version = aws_launch_template.this.latest_version
  }

  # This tells the asg to keep 100% of your desired capacity healthy before it starts terminating old instances,
  # and allows it to exceed capacity by up to 50% during replacements.
  # This coincides with instance_refresher block to get 'launch before terminate' behavior.
  instance_maintenance_policy {
    min_healthy_percentage = 100
    max_healthy_percentage = 150
  }

  # Instance Refresh notes:
  # - A refresh is started when any of the following Auto Scaling Group properties change: launch_configuration, launch_template, mixed_instances_policy. Additional properties can be specified in the triggers property of instance_refresh.
  # - A refresh will not start when version = "$Latest" is configured in the launch_template block. To trigger the instance refresh when a launch template is changed, configure version to use the latest_version attribute of the aws_launch_template resource.
  # - Auto Scaling Groups support up to one active instance refresh at a time. When this resource is updated, any existing refresh is cancelled.
  # - Depending on health check settings and group size, an instance refresh may take a long time or fail. This resource does not wait for the instance refresh to complete.
  #
  # min_healthy_percentage = 100 ensures new instances are brought up before any old ones are taken down
  dynamic "instance_refresh" {
    for_each = local.instance_refresh

    content {
      strategy = "Rolling"
      preferences {
        min_healthy_percentage = 100
        instance_warmup        = 300
      }
    }
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


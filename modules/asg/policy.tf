locals {
  asg_policy_scale_out_name = format(local.name_fmt, var.env_prefix, "scale-out")
  asg_policy_scale_in_name  = format(local.name_fmt, var.env_prefix, "scale-in")
}

resource "aws_autoscaling_policy" "this_scale_in" {
  name                   = local.asg_policy_scale_in_name
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}

resource "aws_autoscaling_policy" "this_scale_out" {
  name                   = local.asg_policy_scale_out_name
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.this.name
}


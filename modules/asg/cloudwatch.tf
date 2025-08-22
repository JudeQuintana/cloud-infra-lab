### CoudWatch Alarms for Scaling in and out
# scale out based on cpu
locals {
  cloudwatch_alarm_cpu_high_name = format(local.name_fmt, local.name, "cpu-high")
  cloudwatch_alarm_cpu_low_name  = format(local.name_fmt, local.name, "cpu-low")
}

resource "aws_cloudwatch_metric_alarm" "this_cpu_high" {
  alarm_name          = local.cloudwatch_alarm_cpu_high_name
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.asg.cloudwatch_alarms.cpu_high.evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asg.cloudwatch_alarms.cpu_high.period
  statistic           = "Average"
  threshold           = var.asg.cloudwatch_alarms.cpu_high.threshold
  alarm_description   = var.asg.cloudwatch_alarms.cpu_high.description
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = [aws_autoscaling_policy.this_scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "this_cpu_low" {
  alarm_name          = local.cloudwatch_alarm_cpu_low_name
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = var.asg.cloudwatch_alarms.cpu_low.evaluation_periods
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = var.asg.cloudwatch_alarms.cpu_low.period
  statistic           = "Average"
  threshold           = var.asg.cloudwatch_alarms.cpu_low.threshold
  alarm_description   = var.asg.cloudwatch_alarms.cpu_low.description
  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.this.name
  }

  alarm_actions = [aws_autoscaling_policy.this_scale_in.arn]
}


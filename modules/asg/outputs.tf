output "id" {
  value = aws_autoscaling_group.this.id
}

output "instance_refresh" {
  value = var.asg.instance_refresh
}

output "ssm" {
  value = var.asg.ssm
}


output "id" {
  value = aws_lb.this.id
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}


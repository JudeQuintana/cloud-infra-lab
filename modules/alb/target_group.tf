resource "aws_lb_target_group" "this" {
  name     = local.name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.alb.vpc_with_subnet_ids.vpc.id

  health_check {
    path                = var.alb.target_group_health_check.path
    matcher             = var.alb.target_group_health_check.matcher
    healthy_threshold   = var.alb.target_group_health_check.healthy_threshold
    unhealthy_threshold = var.alb.target_group_health_check.unhealthy_threshold
    interval            = var.alb.target_group_health_check.interval
    timeout             = var.alb.target_group_health_check.timeout
  }
}


data "aws_region" "this" {}

locals {
  region = data.aws_region.this.name
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)

  alb_name = format("%s-%s-%s", var.env_prefix, var.alb.name, "alb")
}

resource "aws_lb" "this" {
  name               = local.alb_name
  load_balancer_type = "application"
  security_groups    = var.alb.security_group_ids
  subnets            = var.alb.vpc_with_selected_subnet_ids.subnet_ids
  tags               = local.default_tags
}

### Target Group
resource "aws_lb_target_group" "this" {
  name     = local.alb_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.alb.vpc_with_selected_subnet_ids.vpc.id

  health_check {
    path                = var.alb.target_group_health_check.path
    matcher             = var.alb.target_group_health_check.matcher
    healthy_threshold   = var.alb.target_group_health_check.healthy_threshold
    unhealthy_threshold = var.alb.target_group_health_check.unhealthy_threshold
    interval            = var.alb.target_group_health_check.interval
    timeout             = var.alb.target_group_health_check.timeout
  }
}

resource "aws_lb_listener" "this_http_to_https_redirect" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = 443
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "this_https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = var.alb.https_listener.ssl_policy
  certificate_arn   = aws_acm_certificate_validation.this.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }
}

resource "aws_route53_record" "this_alb_cname" {
  zone_id = var.alb.zone.zone_id
  name    = var.alb.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.this.dns_name]
}


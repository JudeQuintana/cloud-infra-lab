locals {
  domain_name = format("%s.%s", "cloud", var.zone_name) # cloud.jq1.io
}

### Existing DNS zone
data "aws_route53_zone" "zone" {
  name = var.zone_name
}

### ACM Certificate (DNS Validated)
resource "aws_acm_certificate" "cert" {
  domain_name       = local.domain_name
  validation_method = "DNS"
}

locals {
  cert_validation_options = { for this in aws_acm_certificate.cert.domain_validation_options : this.domain_name => this }
}

resource "aws_route53_record" "cert_validation" {
  for_each = local.cert_validation_options

  zone_id = data.aws_route53_zone.zone.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
}

locals {
  cert_validation_record_fqdns = [for this in aws_route53_record.cert_validation : this.fqdn]
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn         = aws_acm_certificate.cert.arn
  validation_record_fqdns = local.cert_validation_record_fqdns
}

### ALB
### Target Group
resource "aws_lb" "alb" {
  name               = "app-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets = [
    lookup(lookup(module.vpcs, local.vpc_names.app).public_subnet_name_to_subnet_id, "lb1"),
    lookup(lookup(module.vpcs, local.vpc_names.app).public_subnet_name_to_subnet_id, "lb2")
  ]
}

resource "aws_lb_target_group" "tg" {
  name     = "app-alb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = lookup(module.vpcs, local.vpc_names.app).id

  health_check {
    path                = "/"
    matcher             = "200"
    healthy_threshold   = 3
    unhealthy_threshold = 3
    interval            = 30
    timeout             = 5
  }
}

resource "aws_lb_listener" "http_to_https_redirect" {
  load_balancer_arn = aws_lb.alb.arn
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

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-0-2021-06"
  certificate_arn   = aws_acm_certificate_validation.cert.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

### DNS Record
resource "aws_route53_record" "alb_cname" {
  zone_id = data.aws_route53_zone.zone.zone_id
  name    = local.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.alb.dns_name]
}


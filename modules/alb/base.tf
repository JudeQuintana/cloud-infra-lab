locals {
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)
  name_fmt = "%s-%s"
  name     = format(local.name_fmt, var.env_prefix, var.alb.name)
}

resource "aws_lb" "this" {
  name               = local.name
  load_balancer_type = "application"
  security_groups    = var.alb.security_group_ids
  subnets            = var.alb.subnet_ids
  tags               = local.default_tags
}

resource "aws_route53_record" "this_alb_cname" {
  zone_id = var.alb.zone.zone_id
  name    = var.alb.domain_name
  type    = "CNAME"
  ttl     = 300
  records = [aws_lb.this.dns_name]
}


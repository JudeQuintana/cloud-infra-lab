### ACM Certificate (DNS Validated)
resource "aws_acm_certificate" "this" {
  domain_name       = var.alb.domain_name
  validation_method = "DNS"
}

locals {
  cert_validation_options = { for this in aws_acm_certificate.this.domain_validation_options : this.domain_name => this }
}

resource "aws_route53_record" "this_cert_validation" {
  for_each = local.cert_validation_options

  #zone_id = data.aws_route53_zone.zone.zone_id
  zone_id = var.alb.zone.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  records = [each.value.resource_record_value]
  ttl     = 300
}

locals {
  cert_validation_record_fqdns = [for this in aws_route53_record.this_cert_validation : this.fqdn]
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = local.cert_validation_record_fqdns
}


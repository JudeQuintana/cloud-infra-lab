### Existing DNS zone
data "aws_route53_zone" "zone" {
  name = var.zone_name
}

locals {
  domain_name = format("%s.%s", "cloud", var.zone_name) # cloud.some.domain
}

module "alb" {
  source = "./modules/alb"

  env_prefix = var.env_prefix
  alb = {
    name               = "app"
    zone               = data.aws_route53_zone.zone
    domain_name        = local.domain_name
    security_group_ids = [aws_security_group.alb.id]
    vpc_with_subnet_ids = {
      vpc = local.app_vpc
      subnet_ids = [
        lookup(local.app_vpc.public_subnet_name_to_subnet_id, "lb1"),
        lookup(local.app_vpc.public_subnet_name_to_subnet_id, "lb2")
      ]
    }
  }
}


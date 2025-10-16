data "aws_region" "this" {}

locals {
  default_tags = merge({
    Environment = var.env_prefix
  }, var.tags)
  region         = data.aws_region.this.name
  ipam_name      = format("%s-%s", var.env_prefix, var.ipam.name)
  ipv4_pool_name = format("%s-%s-%s", local.ipam_name, "private", local.region)
  # auto include the module provider region
  operating_regions = toset(concat([local.region], var.ipam.operating_regions))
  provision_cidrs   = toset(var.ipam.provision_cidrs)
}

# default advanced tier
resource "aws_vpc_ipam" "this" {
  description = local.ipam_name

  tags = merge(
    local.default_tags,
    { Name = local.ipam_name }
  )

  dynamic "operating_regions" {
    for_each = local.operating_regions

    content {
      region_name = operating_regions.value
    }
  }
}


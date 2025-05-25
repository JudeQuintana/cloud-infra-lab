# pull region from provider
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}


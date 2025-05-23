# base region
provider "aws" {
  region = "us-west-2"
}

# pull region from aws provider
data "aws_region" "current" {}

locals {
  region = data.aws_region.current.name
}

provider "random" {}

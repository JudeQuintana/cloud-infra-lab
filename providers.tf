# base region
provider "aws" {
  region = "us-west-2"
}

# pull region from aws provider
data "aws_region" "current" {}

provider "random" {}

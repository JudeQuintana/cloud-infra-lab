terraform {
  required_version = "~>1.5"
  required_providers {
    aws = {
      source = "hashicorp/aws"
      # the AWS 6.9+ provider version will also work here but will show deprecations that havent been updated
      version = "~>5.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.7"
    }
  }
}


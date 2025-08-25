terraform {
  required_version = ">=1.5" # using strcontains
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.61"
    }
  }
}


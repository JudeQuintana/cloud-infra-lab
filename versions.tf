terraform {
  required_version = "~>1.4"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.100"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.7"
    }
  }
}


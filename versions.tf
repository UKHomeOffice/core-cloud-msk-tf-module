terraform {
  required_version = ">= 1.9.3"
  required_providers {
    aws = {
      region  = "eu-west-2"
      source  = "hashicorp/aws"
      version = ">= 5.88.0"
    }
  }
}
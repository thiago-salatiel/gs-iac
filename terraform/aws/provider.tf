terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.23"
    }
  }
  backend "s3" {
    bucket         = "gs-iac-rm551050"
    key            = "terraform.tfstate"
    dynamodb_table = "gs-iac-rm551050"
    region         = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}
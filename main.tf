terraform {

  backend "s3" {
    encrypt = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "> 4.16"
    }
  }
}

provider "aws" {
  region = "eu-west-1"
}

locals {
  name   = basename(path.cwd)
  region = "eu-west-1"
  tags = {
    TF-Name     = basename(path.cwd)
    Environment = var.environment
    Repo        = "https://github.com/johnmccuk/${basename(path.cwd)}.git"
  }
}

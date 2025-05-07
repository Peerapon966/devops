terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.94.0"
      configuration_aliases = [aws.virginia]
    }
  }

  backend "s3" {
    bucket       = "terraform-remote-state-bucket-019498b7"
    key          = "devops/dev.tfstate"
    region       = "ap-southeast-1"
    profile      = "dev"
    use_lockfile = true
  }
}

provider "aws" {
  region  = var.region
  profile = var.profile
}

provider "aws" {
  region  = "us-east-1"
  profile = var.profile
  alias   = "virginia"
}
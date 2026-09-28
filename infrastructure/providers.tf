terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
  }
  required_version = "~>1.16.0"
}

provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "cloud_lab" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "aws-cloud-lab"
  }
}

locals {
  subnets = {
    public_a = {
      cidr      = "10.0.0.0/24"
      az        = "us-east-1a"
      public_ip = true
      name      = "aws-public-1a"
    }

    public_b = {
      cidr      = "10.0.1.0/24"
      az        = "us-east-1b"
      public_ip = true
      name      = "aws-public-1b"
    }

    private_app_a = {
      cidr      = "10.0.2.0/24"
      az        = "us-east-1a"
      public_ip = false
      name      = "aws-private-app-1a"
    }

    private_app_b = {
      cidr      = "10.0.3.0/24"
      az        = "us-east-1b"
      public_ip = false
      name      = "aws-private-app-1b"
    }

    private_db_a = {
      cidr      = "10.0.4.0/24"
      az        = "us-east-1a"
      public_ip = false
      name      = "aws-private-db-1a"
    }

    private_db_b = {
      cidr      = "10.0.5.0/24"
      az        = "us-east-1b"
      public_ip = false
      name      = "aws-private-db-1b"
    }
  }
}

resource "aws_subnet" "subnets" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.cloud_lab.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.public_ip

  tags = {
    Name = each.value.name
  }
}

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

  route_tables = {
    public = {
      name = "aws-public-rt"
    }

    private_app_a = {
      name = "aws-private-app-rt-1a"
    }

    private_app_b = {
      name = "aws-private-app-rt-1b"
    }

    private_db = {
      name = "aws-private-db-rt"
    }
  }

  public_subnets = {
    for key, subnet in local.subnets :
    key => subnet
    if subnet.public_ip
  }

  db_subnets = {
    for key, subnet in local.subnets :
    key => subnet
    if startswith(key, "private_db")
  }

  app_subnets = {
    for key, subnet in local.subnets :
    key => subnet
    if startswith(key, "private_app")
  }

  app_route_tables = {
    for key, route_table in local.route_tables :
    key => route_table
    if startswith(key, "private_app")
  }
}

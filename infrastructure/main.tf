resource "aws_vpc" "cloud_lab" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "aws-cloud-lab"
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

resource "aws_internet_gateway" "cloud_lab" {
  vpc_id = aws_vpc.cloud_lab.id

  tags = {
    Name = "aws-cloud-lab-igw"
  }
}

resource "aws_route_table" "route_tables" {
  for_each = local.route_tables

  vpc_id = aws_vpc.cloud_lab.id

  tags = {
    Name = each.value.name
  }
}

resource "aws_route_table_association" "public" {
  for_each = local.public_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables["public"].id
}

resource "aws_route_table_association" "private_db" {
  for_each = local.db_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables["private_db"].id
}

resource "aws_route_table_association" "private_app" {
  for_each = local.app_subnets

  subnet_id      = aws_subnet.subnets[each.key].id
  route_table_id = aws_route_table.route_tables[each.key].id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.route_tables["public"].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.cloud_lab.id
}

resource "aws_eip" "nat_a" {
  domain = "vpc"

  tags = {
    Name = "aws_eip_nat_a"
  }
}

resource "aws_eip" "nat_b" {
  domain = "vpc"
  tags = {
    Name = "aws_eip_nat_b"
  }
}

resource "aws_nat_gateway" "nat_gw_a" {
  allocation_id = aws_eip.nat_a.id
  subnet_id     = aws_subnet.subnets["public_a"].id

  tags = {
    Name = "aws_nat_gw_a"
  }
}

resource "aws_nat_gateway" "nat_gw_b" {
  allocation_id = aws_eip.nat_b.id
  subnet_id     = aws_subnet.subnets["public_b"].id

  tags = {
    Name = "aws_nat_gw_b"
  }
}

resource "aws_route" "private_app_a_internet_access" {
  route_table_id         = aws_route_table.route_tables["private_app_a"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw_a.id
}

resource "aws_route" "private_app_b_internet_access" {
  route_table_id         = aws_route_table.route_tables["private_app_b"].id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw_b.id
}

resource "aws_security_group" "security_groups" {
  for_each = local.security_groups

  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.cloud_lab.id

  tags = {
    Name = each.value.name
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_allow_http_ingress" {
  security_group_id = aws_security_group.security_groups["alb_sg"].id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80

  tags = {
    Name = "alb_allow_http_ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "alb_egress_to_app" {
  security_group_id            = aws_security_group.security_groups["alb_sg"].id
  referenced_security_group_id = aws_security_group.security_groups["app_sg"].id

  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8000

  tags = {
    Name = "alb_egress_to_app"
  }
}

resource "aws_vpc_security_group_ingress_rule" "app_allow_alb_ingress" {
  security_group_id            = aws_security_group.security_groups["app_sg"].id
  referenced_security_group_id = aws_security_group.security_groups["alb_sg"].id

  ip_protocol = "tcp"
  from_port   = 8000
  to_port     = 8000
  description = "Allow inbound traffic from the ALB SG via port 8000"

  tags = {
    Name = "app_allow_alb_ingress"
  }
}

resource "aws_vpc_security_group_egress_rule" "app_egress_to_internet" {
  security_group_id = aws_security_group.security_groups["app_sg"].id

  cidr_ipv4   = "0.0.0.0/0"
  ip_protocol = "-1" # allow all traffic

  tags = {
    Name = "app_egress_to_internet"
  }
}

resource "aws_lb" "alb" {
  name               = "aws-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.security_groups["alb_sg"].id]
  subnets = [
    for key, subnet in local.public_subnets :
    aws_subnet.subnets[key].id
  ]
}

# iam
resource "aws_iam_role" "app_ec2_role" {
  name = "app_ec2_role"

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "ec2.amazonaws.com"
            ]
          }
        }
      ]
    }
  )
  tags = {
    tag-key = "app_ec2_role"
  }
}

resource "aws_iam_role_policy_attachment" "cloudwatch_agent_policy_attachment" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "systems_manager_session_manager" {
  role       = aws_iam_role.app_ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_ec2" {
  name = "app_ec2"
  role = aws_iam_role.app_ec2_role.name
}

# compute
resource "aws_launch_template" "aws_cloud_lab" {
  name = "lab_launch_template"

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  iam_instance_profile {
    name = aws_iam_instance_profile.app_ec2.name
  }

  # image_id = "ami-test"
  image_id = "ami-0d27e0fb3bac4d724"

  instance_type = "t3.micro"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  # vpc_security_group_ids = ["sg-12345678"]
  vpc_security_group_ids = [aws_security_group.security_groups["app_sg"].id]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "aws_cloud_lab"
    }
  }

  # user_data = filebase64("${path.module}/example.sh")
  user_data = base64encode(<<-EOF
  #!/bin/bash
  set -e # tells Bash to exit if a command fails, rather than continuing with a broken setup
  
  sudo dnf upgrade -y
  sudo dnf install docker -y
  sudo systemctl enable --now docker

  docker pull rlop4/aws-cloud-lab:1.2
  docker run -d --restart always --name aws-cloud-lab -p 8000:8000 rlop4/aws-cloud-lab:1.2
  EOF
  )
}


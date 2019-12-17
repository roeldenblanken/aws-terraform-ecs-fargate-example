locals {
  my_name  = "${var.prefix}-${var.env}-vpc"
  my_deployment   = "${var.prefix}-${var.env}"
}

# Examples, see: https://github.com/terraform-aws-modules/terraform-aws-vpc

data "aws_availability_zones" "available" {}


resource "aws_vpc" "ecs-vpc" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name        = local.my_name
    Deployment  = local.my_deployment
    Prefix      = var.prefix
    Environment = var.env
    Region      = var.region
    Terraform   = "true"
  }
}

# See: https://aws.amazon.com/blogs/compute/task-networking-in-aws-fargate/
# Chapter "Private subnets
resource "aws_internet_gateway" "internet-gateway" {
  vpc_id = aws_vpc.ecs-vpc.id

  tags = {
    Name        = "${local.my_name}-ig"
    Deployment  = local.my_deployment
    Prefix      = var.prefix
    Environment = var.env
    Region      = var.region
    Terraform   = "true"
  }
}

# This subnet hosts the Application Load Balancer (ALB) which is exposed to internet and NAT gateway and Bastion host.
resource "aws_subnet" "public-subnet" {
  vpc_id            = aws_vpc.ecs-vpc.id
  count = var.private_subnet_count
  availability_zone = data.aws_availability_zones.available.names[count.index]
  # Assumes that vpc cidr block is format "xx.yy.0.0/16", i.e. we are creating /24 for the last to numbers.
  # NOTE: A bit of a hack. Maybe create a more generic solution here later.
  cidr_block        = replace(var.vpc_cidr_block, ".0.0/16", ".${count.index+10}.0/24")

  tags = {
    Name        = "${local.my_name}-${count.index+10}-public-subnet"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_security_group" "bastion-public-subnet-sg" {
  name        = "${local.my_name}-bastion-public-subnet-sg"
  description = "For testing purposes, create ingress rules manually"
  vpc_id      = aws_vpc.ecs-vpc.id

  # For testing purposes for connecting ssh to test ec2 instance.
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = [var.admin_workstation_ip]
  }

  // Terraform removes the default rule.
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.my_name}-bastion-public-subnet-sg"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_security_group" "alb-public-subnet-sg" {
  name        = "${local.my_name}-alb-public-subnet-sg"
  description = "Allow inbound access to application port only, oubound to ECS"
  vpc_id      = aws_vpc.ecs-vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Terraform removes the default rule.
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.my_name}-alb-public-subnet-sg"
    Deployment  = "${local.my_deployment}"
    Prefix      = var.prefix
    Environment = var.env
    Region      = var.region
    Terraform   = "true"
  }
}

resource "aws_route_table" "public-subnet-route-table" {
  vpc_id = aws_vpc.ecs-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet-gateway.id
  }

  tags = {
    Name        = "${local.my_name}-public-subnet-route-table"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# AWS ECS/Fargate needs EIP/NAT to pull the images.
resource "aws_eip" "nat-gw-eip" {
  vpc = true
  tags = {
    Name        = "${local.my_name}-nat-gw-eip"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# AWS ECS/Fargate needs EIP/NAT to pull the images.
# See: https://aws.amazon.com/blogs/compute/task-networking-in-aws-fargate/
# Chapter "Private subnets
resource "aws_nat_gateway" "nat-gw" {
  allocation_id = aws_eip.nat-gw-eip.id
  subnet_id     = aws_subnet.public-subnet[0].id

  tags = {
    Name        = "${local.my_name}-nat-gw"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# From our public to Internet gateway.
resource "aws_route_table_association" "public-subnet-route-table-association" {
  count = var.private_subnet_count
  subnet_id      = aws_subnet.public-subnet.*.id[count.index]
  route_table_id = aws_route_table.public-subnet-route-table.id
}

# This is the private subnet hosting ECS, Fargate (EC2) and Tasks (Docker containers).
resource "aws_subnet" "ecs-private-subnet" {
  vpc_id            = aws_vpc.ecs-vpc.id
  count             = var.private_subnet_count
  availability_zone = data.aws_availability_zones.available.names[count.index]
  # Assumes that vpc cidr block is format "xx.yy.0.0/16", i.e. we are creating /24 for the last to numbers.
  # NOTE: A bit of a hack. Maybe create a more generic solution here later.
  cidr_block        = replace(var.vpc_cidr_block, ".0.0/16", ".${count.index}.0/24")

  tags = {
    Name        = "${local.my_name}-${count.index}-ecs-private-subnet"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_security_group" "ecs-private-subnet-sg" {
  name        = "${local.my_name}-ecs-private-subnet-sg"
  description = "Allow inbound access from the ALB only"
  vpc_id      = aws_vpc.ecs-vpc.id

  # Accept inbound to app port only from ALB security group.
  ingress {
    protocol        = "tcp"
    from_port       = var.app_port
    to_port         = var.app_port
    security_groups = [aws_security_group.alb-public-subnet-sg.id]
  }

  # For testing purposes for connecting ssh to test ec2 instance from bastion host.
  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    security_groups = [aws_security_group.bastion-public-subnet-sg.id]
  }

  # For testing purposes.
  ingress {
    protocol    = "tcp"
    from_port   = var.app_port
    to_port     = var.app_port
    security_groups = [aws_security_group.bastion-public-subnet-sg.id]
  }

  // Terraform removes the default rule.
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.my_name}-ecs-private-subnet-sg"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_security_group" "database-private-subnet-sg" {
  name        = "${local.my_name}-database-private-subnet-sg"
  description = "Allow inbound access from the ecs only"
  vpc_id      = aws_vpc.ecs-vpc.id

  # Accept inbound to database port only from ecs security group.
  ingress {
    protocol        = "tcp"
    from_port       = var.database_port
    to_port         = var.database_port
    security_groups = [aws_security_group.ecs-private-subnet-sg.id]
  }

  # For testing purposes access from bastion host.
  ingress {
    protocol    = "tcp"
    from_port   = var.database_port
    to_port     = var.database_port
    security_groups = [aws_security_group.bastion-public-subnet-sg.id]
  }

  // Terraform removes the default rule.
  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${local.my_name}-database-private-subnet-sg"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# From ECS private subnet forward to NAT gateway.
# We need this for ECS to pull images from the private subnet.
resource "aws_route_table" "ecs-private-subnet-route-table" {
  vpc_id = aws_vpc.ecs-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat-gw.id
  }

  tags = {
    Name        = "${local.my_name}-ecs-private-subnet-route-table"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# From our ECS private subnet to NAT.
resource "aws_route_table_association" "ecs-private-subnet-route-table-association" {
  count = var.private_subnet_count
  subnet_id      = aws_subnet.ecs-private-subnet.*.id[count.index]
  route_table_id = aws_route_table.ecs-private-subnet-route-table.id
}

# Create a S3 endpoint to route s3 traffic privately
resource "aws_vpc_endpoint" "s3_endpoint" {
  vpc_id            = aws_vpc.ecs-vpc.id
  service_name      = "com.amazonaws.eu-west-1.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.public-subnet-route-table.id, aws_route_table.ecs-private-subnet-route-table.id]

  tags = {
    Name        = "${local.my_name}-alb-s3-log-bucket"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

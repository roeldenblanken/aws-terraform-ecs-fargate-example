locals {
  my_name       = "${var.prefix}-${var.env}-bastion-ec2"
  my_deployment = "${var.prefix}-${var.env}"
  my_key_name   = "Work"
}

resource "aws_iam_instance_profile" "bastion-profile" {
  name = "bastion-profile"
  role = aws_iam_role.bastion-role.name
}

resource "aws_iam_role" "bastion-role" {
  name = "bastion-role"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF

  tags = {
    Name        = "${local.my_name}-bastion-role"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# Allow to get encrypted parameters from the SSM Parameter store
resource "aws_iam_policy" "bastion-policy" {
  name        = "bastion-policy"
  description = "bastion-policy to get SSM Parameters"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
      "Effect": "Allow",
      "Action": [
	    "ssm:GetParameter",
        "ssm:GetParameters",
		"ssm:DescribeParameters"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

data "aws_ami" "latest_aws_linux_2_ami" {
	most_recent = true
	owners 	    = ["amazon"]

    filter {
      name   = "name"
      values = ["amzn2-ami-hvm*"]
    }

    filter {
       name   = "architecture"
       values = ["x86_64"]
    } 
}

resource "aws_instance" "bastion-ec2" {
  ami                    = data.aws_ami.latest_aws_linux_2_ami.id
  instance_type          = "t2.micro"
  vpc_security_group_ids = ["${var.bastion-public-subnet_sg_id}"]
  subnet_id              = var.public_subnet_ids[0][0]
  key_name               = local.my_key_name
  user_data = file("../../modules/bastion/user_data.sh")
	
  tags = {
    Name        = "${local.my_name}-bastion"
    Deployment  = "${local.my_deployment}"
    Prefix      = var.prefix
    Environment = var.env
    Region      = var.region
    Terraform   = "true"
  }
}

resource "aws_eip" "lb" {
  instance = aws_instance.bastion-ec2.id
  vpc      = true
}
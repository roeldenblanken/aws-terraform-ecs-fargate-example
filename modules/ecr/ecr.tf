locals {
  my_name     = "${var.prefix}-${var.env}-ecr"
  my_deployment      = "${var.prefix}-${var.env}"
  my_crm_name = "java-crm-demo"
}

resource "aws_ecr_repository" "ecs-ecr-repository" {
  name = "${local.my_name}-${local.my_crm_name}"

  tags = {
    Name        = local.my_name
    Deployment  = local.my_deployment
    Prefix      = var.prefix
    Environment = var.env
    Region      = var.region
    Terraform   = "true"
  }
}
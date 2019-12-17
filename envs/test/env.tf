# Test environment.
# NOTE: If environment copied, change environment related values (e.g. "test" -> "perf").

##### Terraform configuration #####

# Usage:
# AWS_PROFILE=default terraform init
# AWS_PROFILE=default terraform get
# AWS_PROFILE=default terraform plan
# AWS_PROFILE=default terraform apply

# NOTE: If you want to create a separate version of this demo, use a unique prefix, e.g. "myname-ecs-demo".
# This way all entities have a different name and also you create a dedicate terraform state file
# (remember to call 'terraform destroy' once you are done with your experimentation).
# So, you have to change the prefix in both local below and terraform configuration section in key.

locals {
  # Ireland
  my_region                 = "eu-west-1"
  # Use unique environment names, e.g. dev, test, custqa, qa, test, perf, ci, prod...
  my_env                    = "test"
  # Use consistent prefix, e.g. <cloud-provider>-<demo-target/purpose>-demo, e.g. aws-ecs-demo
  my_prefix                 = "ecs-fargate-demo"
  all_demos_terraform_info  = "blankia-demo"
  # NOTE: Reserve 10.20.*.* address space for this demonstration.
  vpc_cidr_block            = "10.20.0.0/16"
  private_subnet_count      = "2"
  ecs_service_desired_count = 2
  ecr_crm_image_version     = "latest"
  # See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task-cpu-memory-error.html
  fargate_container_memory  = "4096"
  fargate_container_cpu     = "1024"
  app_port                  = "8080"
  database_name     		= "databaseblankia"
  database_user 			= "admin"
  database_port             = "3306"
  color						= "red"
}

# NOTE: You cannot use locals in the terraform configuration since terraform
# configuration does not allow interpolation in the configuration section.
terraform {
  required_version = ">=0.12.18"
  backend "s3" {
    # NOTE: We use the same bucket for storing terraform statefiles for all PC demos (but different key).
    bucket     = "terraform-blankia"
    # NOTE: This must be unique for each demo!!!
    # Use the same prefix and test as in local!
    # I.e. key = "<prefix>/<test>/terraform.tfstate".
    key        = "aws-ecs-fargate-demo/test/terraform.tfstate"
    region     = "eu-west-1"
    # NOTE: We use the same DynamoDB table for locking all state files of all demos. Do not change name.
    dynamodb_table = "blankia-demos-terraform-backends"
    # NOTE: This is AWS account profile, not env! You probably have two accounts: one dev (or test) and one prod.
    profile    = "default"
  }
}

provider "aws" {
  region     = local.my_region
}

# Admin workstation ip, must be injected with
# export TF_VAR_admin_workstation_ip="11.11.11.11/32"
variable "admin_workstation_ip" {}
variable "image" {}
variable "build_number" {}

data "aws_ssm_parameter" "DB_PASSWORD" {
  name = "DB_PASSWORD"
}

# Here we inject our values to the environment definition module which creates all actual resources.
module "env-def" {
  source                    = "../../modules/env-def"
  prefix                    = "${local.my_prefix}"
  env                       = "${local.my_env}"
  region                    = "${local.my_region}"
  vpc_cidr_block            = "${local.vpc_cidr_block}"
  private_subnet_count      = "${local.private_subnet_count}"
  ecs_service_desired_count = "${local.ecs_service_desired_count}"
  image					    = "${var.image}" 
  build_number				= "${var.build_number}" 
  ecr_crm_image_version     = "${local.ecr_crm_image_version}"
  fargate_container_memory  = "${local.fargate_container_memory}"
  fargate_container_cpu     = "${local.fargate_container_cpu}"
  app_port                  = "${local.app_port}"
  admin_workstation_ip      = "${var.admin_workstation_ip}"
  database_name     		= "${local.database_name}"
  database_user 			= "${local.database_user}"
  database_password 		= data.aws_ssm_parameter.DB_PASSWORD.value
  database_password_arn		= data.aws_ssm_parameter.DB_PASSWORD.arn
  database_port             = "${local.database_port}"
  color           			= "${local.color}"
}

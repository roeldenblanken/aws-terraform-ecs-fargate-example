variable "prefix" {}
variable "env" {}
variable "region" {}
variable "ecs_service_desired_count" {}
variable "ecs_private_subnet_az_names" {}
variable "ecs_private_subnet_ids" {
  type = list
}
variable "public_subnet_ids" {
  type = list
}
variable "image" {}
variable "build_number" {}
variable "ecr_image_url" {}
variable "ecr_crm_image_version" {}
variable "fargate_container_memory" {}
variable "fargate_container_cpu" {}
variable "app_port" {}
variable "vpc_id" {}
variable "aws_account_id" {}

variable "alb-public-subnet-sg_id" {}
variable "ecs_private_subnet_sg_id" {}

variable "db_endpoint" {}
variable "db_user" {}
variable "db_password" {}
variable "db_base" {}
variable "db_port" {}
variable "color" {}
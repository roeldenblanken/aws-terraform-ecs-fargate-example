variable "prefix" {}
variable "env" {}
variable "region" {}
variable "bastion-public-subnet_sg_id" {}
	
variable "public_subnet_ids" {
  type = list
}
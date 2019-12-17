locals {
  my_name  = "${var.prefix}-${var.env}-database"
  my_deployment   = "${var.prefix}-${var.env}"
  database_version   = "8.0.16"
  parameter_group_name = "default.mysql8.0"
}

resource "aws_db_subnet_group" "my-dbsg" {
  name        = "${local.my_name}-dbsg"
  description = "my-dbsg"
  subnet_ids  = flatten([var.ecs_private_subnet_ids])
  
  tags = {
    Name        = "${local.my_name}-dbsg"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_db_instance" "my-db" {
  identifier        			= "my-db"
  allocated_storage 			= 20
  storage_type      			= "gp2"
  engine            			= "mysql"
  engine_version    			= local.database_version
  instance_class    			= "db.t2.micro"
  name     						= var.database_name
  username 						= var.database_user
  password 						= var.database_password
  parameter_group_name   		= local.parameter_group_name
  db_subnet_group_name   		= aws_db_subnet_group.my-dbsg.id
  vpc_security_group_ids 		= [var.database_private_subnet_sg_id]
  
  allow_major_version_upgrade 	= true
  auto_minor_version_upgrade  	= true
  backup_window               	= "22:00-23:00"
  maintenance_window          	= "Sat:00:00-Sat:03:00"
  multi_az                    	= true
  apply_immediately 			= true
  
  # set these for dev db
  backup_retention_period 		= 1
  # required for deleting
  skip_final_snapshot       	= true
  final_snapshot_identifier 	= "Ignore"
  
  tags = {
    Name        = "${local.my_name}"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# if needed a read replica
/*resource "aws_db_instance" "my-db-replica" {
  identifier        			= "my-db-replica"
  replicate_source_db			= aws_db_instance.my-db.arn
  allocated_storage 			= 20
  storage_type      			= "gp2"
  engine            			= "mysql"
  engine_version    			= local.database_version
  instance_class    			= "db.t2.micro"
  name     						= var.database_name
  parameter_group_name   		= local.parameter_group_name
  db_subnet_group_name   		= aws_db_subnet_group.my-dbsg.id
  vpc_security_group_ids 		= [var.database_private_subnet_sg_id]
  
  allow_major_version_upgrade 	= true
  auto_minor_version_upgrade  	= true

  maintenance_window          	= "Sat:00:00-Sat:03:00"
  apply_immediately 			= true
  
  # set these for dev db
  backup_retention_period 		= 0
  # required for deleting
  skip_final_snapshot       	= true
  final_snapshot_identifier 	= "Ignore"
  
  tags = {
    Name        = "${local.my_name}"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}
*/
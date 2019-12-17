locals {
  my_name  = "${var.prefix}-${var.env}-ecs"
  my_deployment   = "${var.prefix}-${var.env}"
}

# See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role" "ecs-task-execution-role" {
  name = "${local.my_name}-task-execution-role"

  assume_role_policy = <<ROLEPOLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
ROLEPOLICY

  tags = {
    Name        = "${local.my_name}-task-execution-role"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# See: https://docs.aws.amazon.com/AmazonECS/latest/developerguide/task_execution_IAM_role.html
resource "aws_iam_role_policy_attachment" "ecs-task-execution-role-policy-attachment" {
  role       = aws_iam_role.ecs-task-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "ecs-task-execution-role-policy" {
  name        = "${local.my_name}-policy"
  description = "Get encrypted values from SSM"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
	{
      "Effect": "Allow",
      "Action": [
        "ssm:GetParameters"
      ],
      "Resource": [
        "arn:aws:ssm:eu-west-1:${var.aws_account_id}:parameter/DB_PASSWORD"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "test-attach" {
  role       = aws_iam_role.ecs-task-execution-role.name
  policy_arn = aws_iam_policy.ecs-task-execution-role-policy.arn
}

resource "aws_ecs_cluster" "ecs-cluster" {
  name = "${local.my_name}-cluster"

  tags = {
    Name        = "${local.my_name}-cluster"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

# We could create the task definition file from template so that we inject the image url
# dynamically and we do not expose our AWS account id in json code
# (the image url comprises the AWS account id). But let's put all code explicitely here using inline container definition.
# So, NOTE: Not used in this demo, kept for historical reasons.
data "template_file" "ecs_crm_task_def_template" {
  template = "${file("../../task-definitions/hello-world.json.template")}"
  vars = {
    name					 = "${local.my_name}-crm-container"
    image		             = "${var.image}:${var.ecr_crm_image_version}"
    fargate_container_memory = var.fargate_container_memory
    fargate_container_cpu    = var.fargate_container_cpu
    app_port                 = var.app_port
	db_endpoint				 = var.db_endpoint
	db_user					 = var.db_user
	db_password				 = var.db_password
	db_base					 = var.db_base
	db_port					 = var.db_port
	color					 = var.color	
	build_number			 = var.build_number	
  }
}

resource "aws_ecs_task_definition" "ecs-task-definition" {
  family                   = "${local.my_name}-java-crm-task-definition"
  memory                   = var.fargate_container_memory
  cpu                      = var.fargate_container_cpu
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = aws_iam_role.ecs-task-execution-role.arn

  # Just keeping the template model as a reminder that you can easily template the container definition...
  # container_definitions    = data.template_file.ecs_crm_task_def_template.rendered
  # But let's do the container definition inline here to make it more explicit.
  
  # NOTE: You cannot quote int64 in inline section!!! (I.e., do not close
  # ${var.fargate_container_memory} inside double quotes (").
  
  #"image": "${var.ecr_image_url}:${var.ecr_crm_image_version}",
  
  container_definitions = <<CONTAINERDEFINITION
[
  {
    "name": "${local.my_name}-crm-container",
    "memory": ${var.fargate_container_memory},
    "cpu": ${var.fargate_container_cpu},
	"image": "${var.image}:${var.ecr_crm_image_version}",
    "networkMode": "awsvpc",
    "portMappings": [
      {
        "containerPort": ${var.app_port},
        "hostPort": ${var.app_port},
		"protocol": "tcp"
      }
    ],
	"environment": [
		{
			"name": "DB_ENDPOINT",
			"value": "${var.db_endpoint}"
		},
		{
			"name": "DB_USER",
			"value": "${var.db_user}"
		},
		{
			"name": "DB_BASE",
			"value": "${var.db_base}"
		},
		{
			"name": "DB_PORT",
			"value": "${var.db_port}"
		},
		{
			"name": "COLOR",
			"value": "${var.color}"
		},
		{
			"name": "BUILD_NUMBER",
			"value": "${var.build_number}"
		}
	],
	"secrets": [
      {
        "name": "DB_PASSWORD",
        "valueFrom": "${var.db_password}"
      }
    ]
  }
]
CONTAINERDEFINITION


  tags = {
    Name        = "${local.my_name}-java-crm-task-definition"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
	image 		= "${var.image}:${var.ecr_crm_image_version}"
	build		= "${var.build_number}"
  }

}

# See: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/load-balancer-access-logs.html#access-logging-bucket-permissions
resource "aws_s3_bucket" "ecs-alb-s3-log-bucket" {
  force_destroy = true
  bucket = "${local.my_name}-alb-s3-log-bucket"

  policy = <<BUCKETPOLICY
{
  "Id": "Policy1549706693168",
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1549706688933",
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
			"arn:aws:s3:::${local.my_name}-alb-s3-log-bucket/alb-log/AWSLogs/${var.aws_account_id}/*"
			],
	  "Principal": {
		"AWS": [
			"156460612806"
		]
	  }
    },
	{
		"Sid": "AllowSSLRequestsOnly",
		"Action": "s3:*",
		"Effect": "Deny",
		"Resource": [
			"arn:aws:s3:::${local.my_name}-alb-s3-log-bucket",
			"arn:aws:s3:::${local.my_name}-alb-s3-log-bucket/*"
	],
		"Condition": {
			"Bool": {
				"aws:SecureTransport": "false"
			}
	},
		"Principal": "*"
	}
  ]
}
BUCKETPOLICY

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
  
  tags = {
    Name        = "${local.my_name}-alb-s3-log-bucket"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_s3_bucket_public_access_block" "bucket" {
  bucket = aws_s3_bucket.ecs-alb-s3-log-bucket.id

  block_public_acls   = true
  block_public_policy = true
}

# Application load balancer (ALB) for the system.
# Exposes the ECS tasks to the internet via ALB (with application port only).
resource "aws_alb" "ecs-alb" {
  name               = "${local.my_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = ["${var.alb-public-subnet-sg_id}"]
  subnets            = flatten(["${var.public_subnet_ids}"])
  //enable_deletion_protection = true

  access_logs {
    bucket  = aws_s3_bucket.ecs-alb-s3-log-bucket.bucket
    prefix  = "alb-log"
    enabled = true
  }

  tags = {
    Name        = "${local.my_name}-alb"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.ecs-alb.arn
  port              = var.app_port
  protocol          = "HTTP"

  default_action {
    target_group_arn = aws_alb_target_group.ecs-alb-target-group.arn
    type             = "forward"
  }
}

resource "aws_alb_target_group" "ecs-alb-target-group" {
  name        = "${local.my_name}-alb-tg"
  port        = var.app_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"
  // The application must implement a /health GET API that return 200 if everything ok.
  health_check {
    path = "/"
    matcher = "200"
    interval = "10"
    protocol = "HTTP"
  }

  tags = {
    Name        = "${local.my_name}-alb-tg"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }
}


resource "aws_ecs_service" "ecs-service" {
  name            = "${local.my_name}-service"
  cluster         = aws_ecs_cluster.ecs-cluster.id
  launch_type     = "FARGATE"
  desired_count   = var.ecs_service_desired_count
  task_definition = aws_ecs_task_definition.ecs-task-definition.arn

  network_configuration {
    subnets = flatten(["${var.ecs_private_subnet_ids}"])
    security_groups = ["${var.ecs_private_subnet_sg_id}"]
  }

  load_balancer {
    target_group_arn = aws_alb_target_group.ecs-alb-target-group.arn
    container_name   = "${local.my_name}-crm-container"
    container_port   = var.app_port
  }

  depends_on = [
    aws_alb_listener.alb_listener
  ]

  tags = {
    Name        = "${local.my_name}-service"
    Deployment  = "${local.my_deployment}"
    Prefix      = "${var.prefix}"
    Environment = "${var.env}"
    Region      = "${var.region}"
    Terraform   = "true"
  }

}

output "ecr_name" {
  value = "${aws_ecr_repository.ecs-ecr-repository.name}"
}

output "ecr_id" {
  value = "${aws_ecr_repository.ecs-ecr-repository.id}"
}

# ECS Fargate needs this.
output "ecr_url" {
  value = "${aws_ecr_repository.ecs-ecr-repository.repository_url}"
}
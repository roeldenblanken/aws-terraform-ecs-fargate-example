
# Query as: AWS_PROFILE=YOUR_AWS_PROFILE terraform output -module=env-def.ecs
output "alb_dns_name" {
  value = "${aws_alb.ecs-alb.dns_name}"
}
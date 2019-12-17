output "db_endpoint" {
  description = "The connection endpoint"
  value       = "${aws_db_instance.my-db.address}"
}
output "frontend_alb_dns" {
  description = "Public ALB DNS name for the frontend application."
  value       = aws_lb.frontend.dns_name
}

output "backend_alb_dns" {
  description = "Internal ALB DNS name for the backend API."
  value       = aws_lb.backend.dns_name
}

output "rds_primary_endpoint" {
  description = "Primary RDS MySQL endpoint used by the backend app."
  value       = aws_db_instance.primary.address
}

output "rds_replica_endpoint" {
  description = "Read replica RDS endpoint."
  value       = aws_db_instance.replica.address
}

output "db_name" {
  description = "Database name used by the Book Review app."
  value       = var.db_name
}

output "db_username" {
  description = "Database username configured for the app."
  value       = var.db_username
}

output "web_ssh_private_key_path" {
  description = "Local path to the generated PEM key for web-tier administration."
  value       = local_sensitive_file.web_ssh.filename
}

output "frontend_url" {
  description = "URL to access the Book Review frontend."
  value       = "http://${aws_lb.frontend.dns_name}"
}
output "db_endpoint" {
  description = "Hostname for the RDS instance"
  value       = aws_db_instance.main_db.address
}

output "raw_data_bucket" {
  description = "Bucket for incoming raw data"
  value       = aws_s3_bucket.raw_data_bucket.bucket
}
output "internal_workstation_ip" {
  description = "Public IP of the internal workstation EC2"
  value       = aws_instance.internal_workstation.public_ip
}


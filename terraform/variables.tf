variable "aws_region" {
  type = string
}

variable "allowed_rdp_cidr" {
  type    = string
  default = "0.0.0.0/32"
}

variable "ami_id" {
  type = string
}
variable "project_name" {
  type        = string
  description = "Prefix to use when naming resources in this project"
}
variable "db_password" {
  type        = string
  sensitive   = true
  description = "RDS master user password"
}



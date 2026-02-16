########################
# Database subnet group
########################

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${var.project_name}-db-subnet-group"
  subnet_ids = module.vpc.public_subnets

  tags = {
    Name = "${var.project_name}-db-subnet-group"
  }
}

########################
# Security Group for DB
########################

resource "aws_security_group" "db_sg" {
  name        = "${var.project_name}-db-sg"
  description = "Allow DB access from internal workstation only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Postgres from internal workstation"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [
      aws_security_group.internal_workstation_sg.id
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-db-sg"
  }
}

########################
# RDS Instance (PostgreSQL)
########################

resource "aws_db_instance" "main_db" {
  identifier        = "${var.project_name}-db"
  engine            = "postgres"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "asterra"
  username = "asterra_admin"
  password = "ChangeMe12345!"
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]

  publicly_accessible = true
  skip_final_snapshot = true

  tags = {
    Name        = "${var.project_name}-db"
    Environment = "dev"
  }
}


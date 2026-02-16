module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["eu-central-1a", "eu-central-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.3.0/24"]
  private_subnets = ["10.0.2.0/24", "10.0.4.0/24"]

  create_igw              = true
  enable_nat_gateway      = false
  map_public_ip_on_launch = true

  public_subnet_tags  = { Tier = "public" }
  private_subnet_tags = { Tier = "private" }
}

resource "aws_security_group" "public_web_sg" {
  name        = "public-web-sg"
  description = "Allow HTTP/HTTPS to public server"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["2.54.46.6/32"]
  }
  ingress {
    description = "WordPress admin / dashboard (8080)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group" "internal_workstation_sg" {
  name        = "internal-workstation-sg"
  description = "Allow restricted admin access to internal workstation"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from trusted IP only"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_rdp_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "internal-workstation-sg"
  }
}


resource "aws_key_pair" "public_ec2_key" {
  key_name   = "asterra-public-ec2"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "public_ec2" {
  ami                    = var.ami_id
  instance_type          = "t3.small"
  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.public_web_sg.id]
  key_name               = aws_key_pair.public_ec2_key.key_name
  user_data              = file("${path.module}/user-data-public.sh")

  tags = {
    Name = "asterra-public-ec2"
  }
}
resource "aws_instance" "internal_workstation" {
  ami           = var.ami_id
  instance_type = "t3.small"

  subnet_id              = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.internal_workstation_sg.id]
  key_name               = aws_key_pair.public_ec2_key.key_name

  user_data = file("${path.module}/user-data-internal.sh")

  tags = {
    Name = "asterra-internal-workstation"
  }
}

resource "aws_eip" "public_ip" {
  domain   = "vpc"
  instance = aws_instance.public_ec2.id
  tags     = { Name = "asterra-eip" }
}

output "public_ec2_ip" {
  value = aws_eip.public_ip.public_ip
}

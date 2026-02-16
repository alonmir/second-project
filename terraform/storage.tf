resource "aws_s3_bucket" "raw_data_bucket" {
  bucket = "${var.project_name}-raw-data-${random_integer.suffix.result}"

  tags = {
    Name        = "${var.project_name}-raw-data"
    Environment = "dev"
  }
}

resource "random_integer" "suffix" {
  min = 10000
  max = 99999
}


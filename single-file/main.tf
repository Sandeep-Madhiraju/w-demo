# Main Terraform config: Deploy HashiCat + insecure S3 + Wiz Integration

provider "aws" {
  region = var.region
}

# Generate unique ID for S3 bucket
resource "random_id" "bucket_id" {
  byte_length = 4
}

# Key Pair
resource "aws_key_pair" "hashicat_key" {
  key_name   = "hashicat-key"
  public_key = file(var.public_key_path)
}

# Security Group (insecure for Wiz demo)
resource "aws_security_group" "hashicat_sg" {
  name        = "hashicat-sg"
  description = "Allow all inbound traffic (insecure)"

  ingress {
    from_port   = 0
    to_port     = 65535
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

# EC2 Instance for HashiCat
resource "aws_instance" "hashicat" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.hashicat_key.key_name
  security_groups = [aws_security_group.hashicat_sg.name]

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y apache2 git
              git clone https://github.com/hashicorp/learn-terraform-hashicat.git /var/www/html
              systemctl start apache2
              systemctl enable apache2
              EOF

  tags = {
    Name = "HashiCat-Wiz-Demo"
  }
}

# Fetch Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

# Insecure S3 Bucket
resource "aws_s3_bucket" "hashicat_bucket" {
  bucket = "hashicat-wiz-demo-${random_id.bucket_id.hex}"
  acl    = "public-read"

  website {
    index_document = "index.html"
  }

  tags = {
    Name        = "HashiCat Insecure S3"
    Environment = "Demo"
  }
}

resource "aws_s3_bucket_public_access_block" "no_block_public_access" {
  bucket = aws_s3_bucket.hashicat_bucket.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Wiz IAM Role and Policy
resource "aws_iam_role" "wiz_integration_role" {
  name = "WizIntegrationRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        AWS = var.wiz_account_principal
      },
      Action = "sts:AssumeRole",
      Condition = {
        StringEquals = {
          "sts:ExternalId" = var.wiz_external_id
        }
      }
    }]
  })
}

resource "aws_iam_policy" "wiz_read_only_policy" {
  name   = "WizReadOnlyAccess"
  policy = file("${path.module}/wiz-policy.json")
}

resource "aws_iam_role_policy_attachment" "wiz_attach_policy" {
  role       = aws_iam_role.wiz_integration_role.name
  policy_arn = aws_iam_policy.wiz_read_only_policy.arn
}

# Outputs
output "app_url" {
  value = "http://${aws_instance.hashicat.public_dns}"
}

output "s3_bucket_name" {
  value = aws_s3_bucket.hashicat_bucket.bucket
}

output "wiz_role_arn" {
  value = aws_iam_role.wiz_integration_role.arn
}

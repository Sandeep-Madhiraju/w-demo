provider "aws" {
  region = var.region
}

resource "aws_key_pair" "hashicat_key" {
  key_name   = "hashicat-key"
  public_key = file(var.public_key_path)
}

resource "aws_security_group" "hashicat_sg" {
  name        = "hashicat-sg"
  description = "Allow all inbound traffic (insecure for demo)"

  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # ❌ DELIBERATELY INSECURE
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

output "app_url" {
  value = "http://${aws_instance.hashicat.public_dns}"
}

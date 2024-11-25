terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = "us-west-2"
}

# VPC 10.0.0.0/16
resource "aws_vpc" "le-vpc-25nov-01" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Costcenter = "devops2402"
  }
}

# Subnet public 10.0.1.0/24
resource "aws_subnet" "le-sn-public-01" {
    vpc_id = aws_vpc.le-vpc-25nov-01.id
    cidr_block = "10.0.1.0/24"
    map_public_ip_on_launch = true
    tags = {
        Costcenter = "devops2402"
    }
}

# Subnet private 10.0.2.0/24
resource "aws_subnet" "le-sn-private-01" {
    vpc_id = aws_vpc.le-vpc-25nov-01.id
    cidr_block = "10.0.2.0/24"
    tags = {
        Costcenter = "devops2402"
    }
}

# IGW
resource "aws_internet_gateway" "le-igw-01" {
    vpc_id = aws_vpc.le-vpc-25nov-01.id
    tags = {
        Costcenter = "devops2402"
    }
}

# Route table public
resource "aws_route_table" "le-rtb-public-01" {
  vpc_id = aws_vpc.le-vpc-25nov-01.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.le-igw-01.id
  }
    tags = {
        Costcenter = "devops2402"
    }
}

# Public association
resource "aws_route_table_association" "le-public-association-01" {
  subnet_id = aws_subnet.le-sn-public-01.id
  route_table_id = aws_route_table.le-rtb-public-01.id
}

# Route table private
resource "aws_route_table" "le-rtb-private-01" {
    vpc_id = aws_vpc.le-vpc-25nov-01.id
    tags = {
        Costcenter = "devops2402"
    }
}

# SSH Key Pair
resource "tls_private_key" "generate" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "le-keypair-01" {
  key_name   = "le-keypair-01"
  public_key = tls_private_key.generate.public_key_openssh
    tags = {
        Costcenter = "devops2402"
    }
}

# Save private key locally
resource "local_file" "le-privatekey-01" {
  filename = "le-keypair-01.pem"
  content  = tls_private_key.generate.private_key_pem
  file_permission = "0600"
}

# Public security group
resource "aws_security_group" "le-sg-public-01" {
  vpc_id = aws_vpc.le-vpc-25nov-01.id
  tags = {
    Costcenter = "devops2402"
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Private security group
resource "aws_security_group" "le-sg-private-01" {
  vpc_id = aws_vpc.le-vpc-25nov-01.id
  tags = {
    Costcenter = "devops2402"
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    security_groups = [aws_security_group.le-sg-public-01.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# AMI
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

# Public EC2
resource "aws_instance" "le-ec2-public-01" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    security_groups = [aws_security_group.le-sg-public-01.id]
    subnet_id = aws_subnet.le-sn-public-01.id
    key_name       = aws_key_pair.le-keypair-01.key_name
    tags = {
        Costcenter = "devops2402"
    }
}

# Private EC2
resource "aws_instance" "le-ec2-private-01" {
    ami           = data.aws_ami.ubuntu.id
    instance_type = "t2.micro"
    security_groups = [aws_security_group.le-sg-private-01.id]
    subnet_id = aws_subnet.le-sn-private-01.id
    key_name       = aws_key_pair.le-keypair-01.key_name
    tags = {
        Costcenter = "devops2402"
    }
}

# Output of public IP
output "public_ec2_ip" {
  value = aws_instance.le-ec2-public-01.public_ip
}

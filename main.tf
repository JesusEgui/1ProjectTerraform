# Configure AWS Provider
provider "aws" {
  region = "us-east-1"
}

# Create VPC
resource "aws_vpc" "JenkinsVPC" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "JenkinsVPC"
  }
}

# Create Internet Gateway
resource "aws_internet_gateway" "IGWJenkins" {
  vpc_id = aws_vpc.JenkinsVPC.id
}

# Create a Route Table
resource "aws_route_table" "RTJenkins" {
  vpc_id = aws_vpc.JenkinsVPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.IGWJenkins.id
  }
}

# Associate the Route Table with the Subnet
resource "aws_route_table_association" "jenkins-rt-assoc" {
  subnet_id      = aws_subnet.SubnetJenkins.id
  route_table_id = aws_route_table.RTJenkins.id
}

# Create Subnet within the VPC
resource "aws_subnet" "SubnetJenkins" {
  vpc_id                  = aws_vpc.JenkinsVPC.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "SubnetJenkins"
  }
}

# Generate SSH key pair
resource "tls_private_key" "jenkins-key" {
  algorithm = "RSA"
}

resource "aws_key_pair" "jenkins-key" {
  key_name   = "jenkins-key"
  public_key = tls_private_key.jenkins-key.public_key_openssh
}

# Resource Block To Build EC2 instance
resource "aws_instance" "AlexJenkins" {
  ami           = "ami-067d1e60475437da2"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.jenkins-key.key_name
  user_data     = <<-EOF
    #!/bin/bash
    sudo yum update -y
    sudo wget -O /etc/yum.repos.d/jenkins.repo \
      https://pkg.jenkins.io/redhat-stable/jenkins.repo
    sudo rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
    sudo yum upgrade -y
    sudo amazon-linux-extras install java-openjdk11 -y
    sudo dnf install java-11-amazon-corretto -y
    sudo yum install jenkins -y
    sudo systemctl enable jenkins
    sudo systemctl start jenkins
    sudo systemctl status jenkins
  EOF

  tags = {
    Name = "AlexJenkins"
  }
  vpc_security_group_ids = [aws_security_group.alex_security_group.id]
  subnet_id              = aws_subnet.SubnetJenkins.id
}

# Create security group with SSH and web access
resource "aws_security_group" "alex_security_group" {
  name        = "alex_security_group"
  description = "Allow incoming web traffic from port 80 and 22"
  vpc_id      = aws_vpc.JenkinsVPC.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alex_security_group"
  }
}

# Create S3 bucket for Jenkins Artifacts
resource "aws_s3_bucket" "jenkins_artifacts_bucket" {
  bucket = "bucket-artifacts-alex"  # Cambiado el nombre del bucket para cumplir con las reglas de AWS
  acl    = "private"

  tags = {
    Name = "Jenkins Artifacts Bucket"
  }
}


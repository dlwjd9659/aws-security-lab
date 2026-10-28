###############################################################################
# WARNING - INTENTIONALLY INSECURE
#
# 이 디렉터리의 코드는 보안 실습을 위해 "일부러" 취약하게 작성되었습니다.
# 실제 서비스 환경에 절대 적용하지 마십시오.
# 취약 항목 목록은 README.md 를 참고하세요.
###############################################################################

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project = var.project
      Stage   = "insecure"
      Owner   = "security-lab"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

###############################################################################
# VPC
#
# [취약점] 퍼블릭 서브넷만 만든다. 프라이빗 서브넷이 없으므로
#          DB까지 인터넷에 노출되는 구조가 된다.
###############################################################################

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${var.project}-igw" }
}

# RDS 서브넷 그룹은 서로 다른 AZ 2개를 요구하므로 퍼블릭 서브넷을 2개 만든다.
resource "aws_subnet" "public" {
  count = 2

  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "${var.project}-public-${count.index + 1}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

###############################################################################
# 보안 그룹
#
# [취약점 2] SSH(22), MySQL(3306), HTTP(80/8000)를 0.0.0.0/0 으로 개방한다.
#            Security Hub CIS 벤치마크가 가장 먼저 잡아내는 항목이다.
###############################################################################

resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "INSECURE - world open"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from anywhere (INSECURE)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "App port from anywhere"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-app-sg" }
}

resource "aws_security_group" "db" {
  name        = "${var.project}-db-sg"
  description = "INSECURE - MySQL open to the world"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "MySQL from anywhere (INSECURE)"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-db-sg" }
}

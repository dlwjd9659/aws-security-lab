###############################################################################
# EC2 + IAM
#
# 키페어 없이 운영한다. 접속이 필요하면 Session Manager 를 사용한다.
#   aws ssm start-session --target <instance-id>
###############################################################################

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

###############################################################################
# [취약점 5] EC2 인스턴스 역할에 S3FullAccess 를 그대로 붙인다.
#            이 인스턴스가 탈취되면 계정의 모든 버킷을 읽고 쓸 수 있다.
#            IAM Access Analyzer 의 미사용 권한 분석 대상이 된다.
###############################################################################

resource "aws_iam_role" "ec2" {
  name = "${var.project}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# 과도한 권한 (의도적)
resource "aws_iam_role_policy_attachment" "s3_full" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# Bedrock 전체 권한 (의도적으로 넓게)
resource "aws_iam_role_policy_attachment" "bedrock_full" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonBedrockFullAccess"
}

# Session Manager 접속용 (이건 정상적인 권한)
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.project}-ec2-profile"
  role = aws_iam_role.ec2.name
}

###############################################################################
# EC2 인스턴스
#
# [취약점 4] 루트 EBS 볼륨 암호화 미적용
# [취약점 6] DB 비밀번호를 user_data 환경변수에 평문으로 전달
# [취약점 7] IMDSv1 허용 (http_tokens = "optional")
# [취약점 9] 오래된 베이스 이미지(python:3.8-slim) 사용
###############################################################################

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.app.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  # IMDSv1 허용 (의도적) - SSRF 로 자격증명 탈취가 가능한 상태
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }

  # 루트 볼륨 암호화 미적용 (의도적)
  root_block_device {
    volume_size = 20
    volume_type = "gp3"
    encrypted   = false
  }

  user_data = <<-EOT
    #!/bin/bash
    set -eux

    dnf update -y
    dnf install -y docker
    systemctl enable --now docker

    mkdir -p /opt/app
    cd /opt/app

    # DB 접속 정보를 평문 파일로 저장 (의도적)
    cat > /opt/app/.env <<ENVFILE
    DB_HOST=${aws_db_instance.main.address}
    DB_USER=${var.db_username}
    DB_PASSWORD=${var.db_password}
    DB_NAME=${var.db_name}
    UPLOAD_BUCKET=${aws_s3_bucket.uploads.bucket}
    AWS_REGION=${var.region}
    ENVFILE
    chmod 644 /opt/app/.env

    cat > /opt/app/app.py <<'PYFILE'
    from fastapi import FastAPI

    app = FastAPI()

    @app.get("/")
    def root():
        return {"service": "memo-assistant", "stage": "insecure"}

    @app.get("/health")
    def health():
        return {"ok": True}
    PYFILE

    cat > /opt/app/Dockerfile <<'DOCKERFILE'
    # 의도적으로 오래된 베이스 이미지
    FROM python:3.8-slim
    WORKDIR /app
    RUN pip install --no-cache-dir fastapi==0.95.0 uvicorn==0.21.0
    COPY app.py .
    CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
    DOCKERFILE

    docker build -t memo-app /opt/app
    docker run -d --name memo-app --restart always \
      --env-file /opt/app/.env \
      -p 8000:8000 -p 80:8000 memo-app
  EOT

  user_data_replace_on_change = true

  tags = { Name = "${var.project}-app" }
}

###############################################################################
# S3 버킷
#
# [취약점 1] 업로드 버킷의 퍼블릭 액세스 차단을 모두 해제하고
#            누구나 객체를 읽을 수 있는 버킷 정책을 붙인다.
#            실제 데이터 유출 사고의 가장 흔한 원인이다.
###############################################################################

resource "random_id" "suffix" {
  byte_length = 4
}

# 문서 업로드용 버킷 (퍼블릭)
resource "aws_s3_bucket" "uploads" {
  bucket        = "${var.project}-uploads-${random_id.suffix.hex}"
  force_destroy = true

  tags = { Name = "${var.project}-uploads" }
}

# 퍼블릭 액세스 차단 전면 해제 (의도적)
resource "aws_s3_bucket_public_access_block" "uploads" {
  bucket = aws_s3_bucket.uploads.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# 누구나 읽을 수 있는 정책 (의도적)
resource "aws_s3_bucket_policy" "uploads_public" {
  bucket = aws_s3_bucket.uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadIntentionallyInsecure"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.uploads.arn}/*"
    }]
  })

  depends_on = [aws_s3_bucket_public_access_block.uploads]
}

# 버전 관리 미사용, 암호화 미설정, 액세스 로깅 없음 (의도적)

# 정적 프론트 호스팅용 버킷
resource "aws_s3_bucket" "frontend" {
  bucket        = "${var.project}-frontend-${random_id.suffix.hex}"
  force_destroy = true

  tags = { Name = "${var.project}-frontend" }
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

###############################################################################
# RDS MySQL
#
# [취약점 3] publicly_accessible = true, storage_encrypted = false
#            퍼블릭 서브넷에 배치되고 3306 이 전 세계로 열려 있다.
#            백업 보존 기간 0, 삭제 보호 없음, 감사 로그 없음.
###############################################################################

resource "aws_db_subnet_group" "main" {
  name       = "${var.project}-db-subnet-group"
  subnet_ids = aws_subnet.public[*].id

  tags = { Name = "${var.project}-db-subnet-group" }
}

resource "aws_db_instance" "main" {
  identifier     = "${var.project}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = false # 저장 암호화 미적용 (의도적)

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = true # 인터넷 노출 (의도적)

  backup_retention_period = 0     # 백업 없음 (의도적)
  deletion_protection     = false # 삭제 보호 없음 (의도적)
  skip_final_snapshot     = true
  auto_minor_version_upgrade = false

  tags = { Name = "${var.project}-db" }
}

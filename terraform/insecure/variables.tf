variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "project" {
  description = "리소스 이름 접두사"
  type        = string
  default     = "seclab"
}

variable "instance_type" {
  description = "EC2 인스턴스 타입"
  type        = string
  default     = "t3.micro"
}

variable "db_instance_class" {
  description = "RDS 인스턴스 클래스"
  type        = string
  default     = "db.t4g.micro"
}

variable "db_name" {
  description = "초기 데이터베이스 이름"
  type        = string
  default     = "memodb"
}

variable "db_username" {
  description = "RDS 마스터 사용자명"
  type        = string
  default     = "labadmin"
}

# 기본값을 두지 않는다. terraform.tfvars 에 직접 입력한다.
# 실습 전용 값을 쓰고, 다른 서비스에서 쓰는 비밀번호를 절대 재사용하지 않는다.
variable "db_password" {
  description = "RDS 마스터 비밀번호 (실습 전용)"
  type        = string
  sensitive   = true
}

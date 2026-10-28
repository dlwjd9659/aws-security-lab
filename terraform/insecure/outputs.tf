output "app_public_ip" {
  description = "앱 서버 퍼블릭 IP"
  value       = aws_instance.app.public_ip
}

output "app_url" {
  description = "앱 접속 주소"
  value       = "http://${aws_instance.app.public_ip}"
}

output "instance_id" {
  description = "Session Manager 접속용 인스턴스 ID"
  value       = aws_instance.app.id
}

output "ssm_connect_command" {
  description = "키페어 없이 접속하는 명령"
  value       = "aws ssm start-session --target ${aws_instance.app.id}"
}

output "uploads_bucket" {
  description = "업로드 버킷 (퍼블릭)"
  value       = aws_s3_bucket.uploads.bucket
}

output "frontend_bucket" {
  description = "프론트엔드 버킷"
  value       = aws_s3_bucket.frontend.bucket
}

output "db_endpoint" {
  description = "RDS 엔드포인트 (인터넷 노출 상태)"
  value       = aws_db_instance.main.address
}

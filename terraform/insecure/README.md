# insecure/ — 의도적으로 취약한 구성

이 디렉터리의 코드는 **보안 실습을 위해 일부러 취약하게** 작성되었습니다.
실제 서비스 환경에 적용하지 마십시오.

Day 2 에서 `secure/` 로 교정하며 Before/After 를 비교하기 위한 기준선입니다.

## 심어둔 취약점

| # | 항목 | 위치 | 예상 탐지 |
| --- | --- | --- | --- |
| 1 | S3 업로드 버킷 퍼블릭 읽기 허용 | `storage.tf` | Security Hub, Access Analyzer |
| 2 | 보안그룹 22 / 3306 / 80 을 0.0.0.0/0 개방 | `main.tf` | Security Hub |
| 3 | RDS 퍼블릭 액세스 + 저장 암호화 미적용 | `storage.tf` | Security Hub |
| 4 | 루트 EBS 볼륨 암호화 미적용 | `compute.tf` | Security Hub |
| 5 | EC2 역할에 S3FullAccess / BedrockFullAccess | `compute.tf` | Access Analyzer |
| 6 | DB 비밀번호를 평문 `.env` 파일로 저장 | `compute.tf` | 수동 식별 |
| 7 | IMDSv1 허용 (`http_tokens = "optional"`) | `compute.tf` | Security Hub |
| 8 | CloudTrail 미설정 | 생성하지 않음 | Security Hub |
| 9 | 오래된 베이스 이미지 `python:3.8-slim` | `compute.tf` | Inspector, Trivy |
| 10 | HTTPS 없음, HTTP 평문 통신 | `main.tf` | Security Hub |

추가로 RDS 백업 보존 0일, 삭제 보호 없음, S3 버전 관리·암호화·액세스 로깅 없음,
프라이빗 서브넷 부재 등이 함께 탐지됩니다.

## 실행

```bash
cp terraform.tfvars.example terraform.tfvars
# terraform.tfvars 를 열어 db_password 입력

terraform init
terraform plan
terraform apply
```

RDS 생성에 10~15분이 걸립니다. **기다리는 동안 탐지 서비스 6종을 활성화하세요.**

- CloudTrail
- AWS Config
- Security Hub (CIS AWS Foundations Benchmark 표준)
- GuardDuty
- Amazon Inspector
- IAM Access Analyzer

리전이 **서울(ap-northeast-2)** 인지 반드시 확인합니다.

## 접속

키페어를 만들지 않았으므로 Session Manager 로 접속합니다.

```bash
aws ssm start-session --target $(terraform output -raw instance_id)
```

동작 확인:

```bash
curl http://$(terraform output -raw app_public_ip)/health
```

## 노출 시간 최소화

22번 포트와 3306 포트가 전 세계로 열려 있습니다. 수 분 내에 자동 스캔이
들어옵니다. 그 흔적 자체가 CloudTrail 과 GuardDuty 실습 소재가 되지만,
**필요한 측정이 끝나면 즉시 정리합니다.**

```bash
terraform destroy
```

작업을 중단할 때도 반드시 destroy 하고, 다음 날 다시 apply 하는 편이
안전하고 크레딧도 아낍니다.

## 주의

- `terraform.tfvars` 와 `*.tfstate` 는 절대 커밋하지 않습니다.
  tfstate 에는 DB 비밀번호가 평문으로 들어갑니다.
- 실제 개인정보나 민감 데이터를 올리지 않습니다. 더미 텍스트만 사용합니다.

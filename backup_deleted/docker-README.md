# DSHI Field Pad - Docker 환경 구성 가이드

## 🐳 Docker 환경 설정 완료

Docker를 사용하여 DSHI Field Pad 애플리케이션을 컨테이너화했습니다. 이제 집과 사무실에서 동일한 환경으로 개발할 수 있습니다.

## 📋 구성 요소

### 컨테이너 구성
- **MySQL 8.0**: 데이터베이스 서버 (포트: 3306)
- **Flask API**: Python 백엔드 서버 (포트: 5001)  
- **Sinatra Web**: Ruby 웹 애플리케이션 (포트: 5007)

### 핵심 파일들
- `docker-compose.yml`: 전체 서비스 오케스트레이션
- `Dockerfile.flask`: Flask API 컨테이너 설정
- `test_app/Dockerfile`: Sinatra Web 컨테이너 설정
- `.env`: 환경변수 설정
- `database/init/01-init-database.sql`: MySQL 초기화 스크립트

## 🚀 Docker 실행 방법

### 1. 첫 실행 (초기 설정)
```bash
# 프로젝트 디렉토리로 이동
cd E:\DSHI_RPA\APP

# Docker 컨테이너 빌드 및 실행
docker-compose up --build -d

# 로그 확인
docker-compose logs -f
```

### 2. 일반 실행 (이후 실행)
```bash
# 컨테이너 시작
docker-compose up -d

# 컨테이너 중지
docker-compose down
```

### 3. 완전 재설정 (데이터 초기화)
```bash
# 모든 컨테이너와 볼륨 삭제
docker-compose down -v

# 다시 빌드하여 실행
docker-compose up --build -d
```

## 🔧 환경 설정

### 환경변수 (.env 파일)
```env
# MySQL 설정
MYSQL_ROOT_PASSWORD=dshi_root_2024
MYSQL_DATABASE=dshi_field_pad
MYSQL_USER=dshi_user
MYSQL_PASSWORD=dshi_password_2024

# Flask API 설정
FLASK_HOST=0.0.0.0
FLASK_PORT=5001
FLASK_DEBUG=true

# Sinatra Web 설정
SINATRA_HOST=0.0.0.0
SINATRA_PORT=5007

# API 연결
FLASK_API_URL=http://flask-api:5001
```

## 📊 서비스 접속

### 웹 애플리케이션
- **메인 애플리케이션**: http://localhost:5007
- **Flask API**: http://localhost:5001
- **MySQL**: localhost:3306

### 기본 계정
- **관리자**: admin / admin123 (Level 3)
- **검사원**: inspector1 / admin123 (Level 2)
- **일반사용자**: user1 / admin123 (Level 1)

## 🔍 상태 확인 명령어

```bash
# 컨테이너 상태 확인
docker-compose ps

# 로그 실시간 확인
docker-compose logs -f

# 특정 서비스 로그 확인
docker-compose logs -f web
docker-compose logs -f flask-api
docker-compose logs -f mysql

# 컨테이너 내부 접속
docker-compose exec web bash
docker-compose exec flask-api bash
docker-compose exec mysql mysql -u root -p
```

## 🏠 집에서 작업하기

### Git을 통한 코드 동기화
```bash
# 사무실에서 작업 후 커밋
git add .
git commit -m "작업 내용"
git push origin master

# 집에서 최신 코드 받기
git pull origin master

# Docker 환경 실행
docker-compose up -d
```

### 주의사항
- `.env` 파일의 비밀번호는 보안상 Git에 올리지 않는 것을 권장
- `assembly_data.xlsx` 파일은 실제 데이터이므로 Git 관리 시 주의
- Docker 볼륨을 사용하므로 데이터는 컨테이너 재시작 후에도 유지됨

## 🛠️ 개발 시 유용한 명령어

```bash
# 특정 서비스만 재시작
docker-compose restart web
docker-compose restart flask-api

# 이미지 재빌드 (코드 변경 후)
docker-compose build web
docker-compose build flask-api

# 데이터베이스 백업
docker-compose exec mysql mysqldump -u root -p dshi_field_pad > backup.sql

# 데이터베이스 복원
docker-compose exec -T mysql mysql -u root -p dshi_field_pad < backup.sql
```

## ✅ 완료 상태

모든 Docker 설정이 완료되었습니다:
- ✅ 환경변수 및 의존성 파일 준비
- ✅ Flask API Dockerfile 작성
- ✅ Sinatra Web Dockerfile 작성  
- ✅ docker-compose.yml 오케스트레이션 설정
- ✅ MySQL 초기화 스크립트 준비
- ✅ 개발환경 일관성 확보

이제 `docker-compose up -d` 명령어로 전체 시스템을 실행할 수 있습니다!
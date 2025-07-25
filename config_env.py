# config_env.py - Docker 환경 설정
import os
from dotenv import load_dotenv

# .env 파일 로드 (Docker 컨테이너에서는 환경변수가 자동으로 설정됨)
load_dotenv()

# 데이터베이스 설정
DATABASE_CONFIG = {
    "host": os.getenv("MYSQL_HOST", "localhost"),
    "port": int(os.getenv("MYSQL_PORT", "3306")),
    "database": os.getenv("MYSQL_DATABASE", "dshi_field_pad"),
    "user": os.getenv("MYSQL_USER", "dshi_user"),
    "password": os.getenv("MYSQL_PASSWORD", "dshi_password_2024"),
    "charset": "utf8mb4",
    "autocommit": True
}

# Flask 설정
FLASK_CONFIG = {
    "host": os.getenv("FLASK_HOST", "0.0.0.0"),
    "port": int(os.getenv("FLASK_PORT", "5001")),
    "debug": os.getenv("FLASK_DEBUG", "false").lower() == "true"
}

# 환경 설정
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"

# JWT 설정
JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "dshi-field-pad-secret-key-2024")

# 파일 경로
ASSEMBLY_DATA_FILE = os.getenv("ASSEMBLY_DATA_FILE", "./assembly_data.xlsx")

print(f"🔧 환경 설정 로드됨: {ENVIRONMENT}")
print(f"📊 데이터베이스 호스트: {DATABASE_CONFIG[\"host\"]}")
print(f"🌐 Flask 서버: {FLASK_CONFIG[\"host\"]}:{FLASK_CONFIG[\"port\"]}")

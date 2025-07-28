# config_env.py - Docker 환경 설정
import os
from dotenv import load_dotenv

# .env 파일 로드 (Docker 컨테이너에서는 환경변수가 자동으로 설정됨)
load_dotenv()

# 데이터베이스 설정 (import_data.py와 동일하게)
DATABASE_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "database": "field_app_db",
    "user": "field_app_user",
    "password": "field_app_2024",
    "charset": "utf8mb4"
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

# 함수로 설정 반환
def get_db_config():
    """데이터베이스 설정 반환"""
    return DATABASE_CONFIG

def get_server_config():
    """서버 설정 반환"""
    return FLASK_CONFIG

print(f"환경 설정 로드됨: {ENVIRONMENT}")
print(f"데이터베이스 호스트: {DATABASE_CONFIG['host']}")
print(f"Flask 서버: {FLASK_CONFIG['host']}:{FLASK_CONFIG['port']}")

# config.py

class Config:
    # Flask 앱의 보안을 위한 비밀 키입니다. 실제 운영 환경에서는 더 복잡하고 안전한 값으로 변경해야 합니다.
    SECRET_KEY = 'Mq2LcY5vNzXrT8WaK1HpJq3ZsVb4Xy9'

    # MySQL 데이터베이스 연결 URI (PyMySQL 드라이버 사용)
    # 형식: mysql+pymysql://사용자이름:비밀번호@호스트/데이터베이스이름
    # 'field_app_user'와 'F!eldApp_Pa$$w0rd_2025#'는 이전에 설정한 값으로 변경해야 합니다.
    # 'localhost'는 데이터베이스 서버가 같은 컴퓨터에 있을 경우 사용합니다.
    SQLALCHEMY_DATABASE_URI = 'mysql+pymysql://field_app_user:F!eldApp_Pa$$w0rd_2025#@localhost/field_app_db'
    
    # SQLAlchemy 이벤트 시스템 추적 기능을 비활성화하여 리소스 사용량을 줄입니다.
    SQLALCHEMY_TRACK_MODIFICATIONS = False
# -*- coding: utf-8 -*-
import pymysql

def create_database_and_user():
    try:
        # 먼저 root로 연결 (비밀번호 없이 시도)
        print("MySQL root 계정으로 연결 시도...")
        conn = pymysql.connect(
            host='localhost',
            user='root',
            password='',  # 빈 비밀번호로 시도
            charset='utf8mb4'
        )
        
        cursor = conn.cursor()
        print("MySQL 연결 성공!")
        
        # 데이터베이스 생성
        print("데이터베이스 생성 중...")
        cursor.execute("CREATE DATABASE IF NOT EXISTS field_app_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
        
        # 사용자 생성 및 권한 부여
        print("사용자 생성 및 권한 부여 중...")
        cursor.execute("DROP USER IF EXISTS 'field_app_user'@'localhost';")
        cursor.execute("CREATE USER 'field_app_user'@'localhost' IDENTIFIED BY 'F!eldApp_Pa$w0rd_2025#';")
        cursor.execute("GRANT ALL PRIVILEGES ON field_app_db.* TO 'field_app_user'@'localhost';")
        cursor.execute("FLUSH PRIVILEGES;")
        
        print("데이터베이스 설정 완료!")
        
        # 설정 확인
        cursor.execute("USE field_app_db;")
        cursor.execute("SHOW TABLES;")
        tables = cursor.fetchall()
        print(f"현재 테이블 수: {len(tables)}개")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"오류: {e}")
        return False

if __name__ == "__main__":
    if create_database_and_user():
        print("DB 설정 성공! 이제 애플리케이션을 테스트할 수 있습니다.")
    else:
        print("DB 설정 실패!")

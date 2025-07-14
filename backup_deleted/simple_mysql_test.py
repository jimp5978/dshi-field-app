# -*- coding: utf-8 -*-
import pymysql
from pymysql.cursors import DictCursor

# MySQL 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

def simple_mysql_test():
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("MySQL 연결 성공!")
        
        # assembly_items 데이터 수 확인
        cursor.execute("SELECT COUNT(*) as total FROM assembly_items")
        count = cursor.fetchone()
        print(f"Assembly 데이터 수: {count['total']}개")
        
        # 샘플 데이터 3개
        cursor.execute("SELECT assembly_code, zone, item FROM assembly_items LIMIT 3")
        samples = cursor.fetchall()
        print("샘플 데이터:")
        for sample in samples:
            print(f"  {sample['assembly_code']}: {sample['zone']}, {sample['item']}")
        
        # 사용자 테이블 확인 및 생성
        try:
            cursor.execute("SELECT COUNT(*) as user_count FROM users")
            user_count = cursor.fetchone()['user_count']
            print(f"사용자 데이터 수: {user_count}개")
        except:
            print("사용자 테이블이 없어서 생성합니다...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    full_name VARCHAR(100) NOT NULL,
                    permission_level INT NOT NULL DEFAULT 1
                )
            """)
            
            # 테스트 사용자 추가
            test_users = [
                ('admin', 'admin123', '관리자', 5),
                ('test_level1', 'test123', '외부업체1', 1),
                ('test_level3', 'test123', 'DSHI현장', 3)
            ]
            
            for user in test_users:
                cursor.execute("""
                    INSERT IGNORE INTO users (username, password_hash, full_name, permission_level)
                    VALUES (%s, %s, %s, %s)
                """, user)
            
            conn.commit()
            print("사용자 테이블 생성 및 테스트 계정 추가 완료!")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"MySQL 연결 오류: {e}")
        return False

if __name__ == "__main__":
    print("MySQL 데이터베이스 테스트 시작...")
    if simple_mysql_test():
        print("MySQL 테스트 성공!")
    else:
        print("MySQL 테스트 실패!")

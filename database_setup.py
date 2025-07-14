import mysql.connector
from mysql.connector import Error
import hashlib

# MySQL 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',
    'password': ''
}

def create_database_and_tables():
    """데이터베이스와 테이블 생성"""
    try:
        # MySQL 서버에 연결
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()
        
        # 데이터베이스 생성
        cursor.execute("CREATE DATABASE IF NOT EXISTS dshi_field_pad")
        cursor.execute("USE dshi_field_pad")
        
        # users 테이블 생성
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                username VARCHAR(50) UNIQUE NOT NULL,
                password VARCHAR(255) NOT NULL,
                name VARCHAR(100) NOT NULL,
                created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        # assemblies 테이블 생성
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS assemblies (
                id INT AUTO_INCREMENT PRIMARY KEY,
                assembly_name VARCHAR(200) NOT NULL,
                drawing_number VARCHAR(100) NOT NULL,
                revision VARCHAR(20) DEFAULT 'A',
                status VARCHAR(50) DEFAULT 'active',
                created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)
        
        print("데이터베이스와 테이블이 성공적으로 생성되었습니다.")
        
        # 기본 사용자 추가
        create_default_users(cursor)
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return True
        
    except Error as e:
        print(f"데이터베이스 설정 오류: {e}")
        return False

def create_default_users(cursor):
    """기본 사용자 생성"""
    try:
        # 관리자 계정
        admin_password = hashlib.sha256('admin123'.encode()).hexdigest()
        cursor.execute("""
            INSERT IGNORE INTO users (username, password, name) 
            VALUES (%s, %s, %s)
        """, ('admin', admin_password, '관리자'))
        
        # 테스트 사용자
        test_password = hashlib.sha256('test123'.encode()).hexdigest()
        cursor.execute("""
            INSERT IGNORE INTO users (username, password, name) 
            VALUES (%s, %s, %s)
        """, ('test', test_password, '테스트 사용자'))
        
        print("기본 사용자가 생성되었습니다:")
        print("- 관리자: admin / admin123")
        print("- 테스트: test / test123")
        
    except Error as e:
        print(f"사용자 생성 오류: {e}")

def add_sample_assemblies(cursor):
    """샘플 조립품 데이터 추가"""
    sample_data = [
        ('엔진 블록 어셈블리', 'ENG-001-A', 'Rev.A'),
        ('변속기 하우징', 'TRN-002-B', 'Rev.B'),
        ('유압 실린더', 'HYD-003-A', 'Rev.A'),
        ('컨트롤 패널', 'CTL-004-C', 'Rev.C'),
        ('베어링 하우징', 'BRG-005-A', 'Rev.A')
    ]
    
    try:
        for name, drawing, revision in sample_data:
            cursor.execute("""
                INSERT IGNORE INTO assemblies (assembly_name, drawing_number, revision) 
                VALUES (%s, %s, %s)
            """, (name, drawing, revision))
        
        print("샘플 조립품 데이터가 추가되었습니다.")
        
    except Error as e:
        print(f"샘플 데이터 추가 오류: {e}")

if __name__ == '__main__':
    print("DSHI Field Pad 데이터베이스 설정을 시작합니다...")
    
    if create_database_and_tables():
        print("데이터베이스 설정이 완료되었습니다.")
        
        # 샘플 데이터 추가 여부 확인
        add_sample = input("샘플 조립품 데이터를 추가하시겠습니까? (y/n): ")
        if add_sample.lower() == 'y':
            try:
                connection = mysql.connector.connect(**DB_CONFIG)
                connection.database = 'dshi_field_pad'
                cursor = connection.cursor()
                add_sample_assemblies(cursor)
                connection.commit()
                cursor.close()
                connection.close()
            except Error as e:
                print(f"샘플 데이터 추가 중 오류: {e}")
    else:
        print("데이터베이스 설정에 실패했습니다.")
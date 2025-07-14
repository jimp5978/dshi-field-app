import pymysql
from pymysql.cursors import DictCursor
import hashlib

# 데이터베이스 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

def update_database_schema():
    """레벨 기반 권한 시스템을 위한 데이터베이스 스키마 업데이트"""
    conn = None
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("데이터베이스 스키마 업데이트 시작...")
        
        # 1. 사용자 관리 테이블 생성
        print("\\n사용자 관리 테이블 생성...")
        
        # users 테이블
        users_sql = """
        CREATE TABLE IF NOT EXISTS users (
            id INT AUTO_INCREMENT PRIMARY KEY,
            username VARCHAR(50) NOT NULL UNIQUE,
            password_hash VARCHAR(255) NOT NULL,
            full_name VARCHAR(100) NOT NULL,
            permission_level TINYINT NOT NULL CHECK (permission_level BETWEEN 1 AND 5),
            is_active TINYINT(1) DEFAULT 1,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_username (username),
            INDEX idx_permission_level (permission_level)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(users_sql)
        print("users 테이블 생성 완료")
        
        # dshi_staff 테이블
        dshi_staff_sql = """
        CREATE TABLE IF NOT EXISTS dshi_staff (
            user_id INT PRIMARY KEY,
            department VARCHAR(100) NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(dshi_staff_sql)
        print("dshi_staff 테이블 생성 완료")
        
        # external_users 테이블
        external_users_sql = """
        CREATE TABLE IF NOT EXISTS external_users (
            user_id INT PRIMARY KEY,
            company_name VARCHAR(200) NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(external_users_sql)
        print("external_users 테이블 생성 완료")
        
        # 2. 롤백 사유 마스터 테이블
        print("\\n롤백 사유 마스터 테이블 생성...")
        rollback_reasons_sql = """
        CREATE TABLE IF NOT EXISTS rollback_reasons (
            id INT AUTO_INCREMENT PRIMARY KEY,
            reason_text VARCHAR(200) NOT NULL,
            display_order INT NOT NULL,
            INDEX idx_display_order (display_order)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(rollback_reasons_sql)
        print("rollback_reasons 테이블 생성 완료")
        
        # 롤백 사유 기본 데이터 삽입
        rollback_data = [
            (1, '검사 불합격으로 인한 재작업'),
            (2, '품질 이슈 발견'),
            (3, '도면 변경으로 인한 재작업'),
            (4, '실수로 잘못 진행됨'),
            (5, '장비 문제로 재작업 필요'),
            (6, '고객 요청사항 변경'),
            (7, '기타')
        ]
        
        for order, reason in rollback_data:
            cursor.execute("""
                INSERT IGNORE INTO rollback_reasons (display_order, reason_text)
                VALUES (%s, %s)
            """, (order, reason))
        
        print("롤백 사유 기본 데이터 삽입 완료")
        
        # 3. 로그 테이블 생성
        print("\\n로그 테이블 생성...")
        
        # process_logs 테이블
        process_logs_sql = """
        CREATE TABLE IF NOT EXISTS process_logs (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            user_name VARCHAR(100) NOT NULL,
            assembly_code VARCHAR(50) NOT NULL,
            process_name VARCHAR(50) NOT NULL,
            action ENUM('START','CANCEL') NOT NULL,
            action_date DATETIME NOT NULL,
            rollback_reason_id INT,
            notes TEXT,
            FOREIGN KEY (user_id) REFERENCES users(id),
            FOREIGN KEY (rollback_reason_id) REFERENCES rollback_reasons(id),
            INDEX idx_assembly_code (assembly_code),
            INDEX idx_action_date (action_date)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(process_logs_sql)
        print("process_logs 테이블 생성 완료")
        
        conn.commit()
        print("\\n데이터베이스 스키마 업데이트 완료!")
        return True
        
    except Exception as e:
        print(f"스키마 업데이트 오류: {e}")
        if conn:
            conn.rollback()
        return False
        
    finally:
        if conn:
            conn.close()

def create_default_admin():
    """기본 관리자 계정 생성"""
    conn = None
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # 기본 관리자 계정 생성 (비밀번호: admin123)
        password_hash = hashlib.sha256('admin123'.encode()).hexdigest()
        
        cursor.execute("""
            INSERT IGNORE INTO users (username, password_hash, full_name, permission_level)
            VALUES ('admin', %s, '시스템 관리자', 5)
        """, (password_hash,))
        
        if cursor.rowcount > 0:
            print("기본 관리자 계정 생성 완료 (admin/admin123)")
        else:
            print("기본 관리자 계정이 이미 존재합니다")
        
        # 테스트 사용자들 생성
        test_users = [
            ('test_level1', 'test123', 'Level1 User', 1),
            ('test_level2', 'test123', 'Level2 User', 2),
            ('test_level3', 'test123', 'Level3 User', 3),
            ('test_level4', 'test123', 'Level4 User', 4),
            ('test_level5', 'test123', 'Level5 User', 5)
        ]
        
        for username, password, full_name, level in test_users:
            password_hash = hashlib.sha256(password.encode()).hexdigest()
            
            cursor.execute("""
                INSERT IGNORE INTO users (username, password_hash, full_name, permission_level)
                VALUES (%s, %s, %s, %s)
            """, (username, password_hash, full_name, level))
            
            if cursor.rowcount > 0:
                print(f"테스트 사용자 생성: {username} / {password} (레벨 {level})")
            else:
                print(f"테스트 사용자 이미 존재: {username}")
        
        conn.commit()
        
    except Exception as e:
        print(f"관리자 계정 생성 오류: {e}")
        if conn:
            conn.rollback()
        
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    print("DSHI Field Pad App 스키마 업데이트 시작...")
    print("=" * 60)
    
    if update_database_schema():
        create_default_admin()
        print("\\n" + "=" * 60)
        print("모든 업데이트 완료!")
        print("기본 관리자: admin / admin123")
    else:
        print("스키마 업데이트 실패")

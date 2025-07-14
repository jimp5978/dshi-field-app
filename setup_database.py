import pymysql
from pymysql.cursors import DictCursor

# 데이터베이스 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

def create_tables():
    """데이터베이스 테이블 생성"""
    conn = None
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("🗄️ 데이터베이스 테이블 생성 시작...")
        
        # 1. assembly_items 테이블 생성
        print("\n1️⃣ assembly_items 테이블 생성 중...")
        assembly_items_sql = """
        CREATE TABLE IF NOT EXISTS assembly_items (
            id INT AUTO_INCREMENT PRIMARY KEY,
            assembly_code VARCHAR(50) NOT NULL UNIQUE,
            zone VARCHAR(50),
            item VARCHAR(100),
            fit_up_date DATE,
            nde_date DATE,
            vidi_date DATE,
            galv_date DATE,
            shot_date DATE,
            paint_date DATE,
            packing_date DATE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            INDEX idx_assembly_code (assembly_code),
            INDEX idx_zone (zone)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(assembly_items_sql)
        print("✅ assembly_items 테이블 생성 완료")
        
        # 2. process_definitions 테이블 생성
        print("\n2️⃣ process_definitions 테이블 생성 중...")
        process_definitions_sql = """
        CREATE TABLE IF NOT EXISTS process_definitions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            process_name VARCHAR(50) NOT NULL UNIQUE,
            process_order INT NOT NULL,
            description VARCHAR(200),
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_process_order (process_order)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        cursor.execute(process_definitions_sql)
        print("✅ process_definitions 테이블 생성 완료")
        
        # 3. 공정 정의 데이터 삽입
        print("\n3️⃣ 공정 정의 데이터 삽입 중...")
        process_data = [
            ('Fit-up', 1, '조립/맞춤 공정'),
            ('NDE', 2, '비파괴검사 공정'),
            ('VIDI', 3, 'VIDI 검사 공정'),
            ('GALV', 4, '도금 공정'),
            ('SHOT', 5, '샷블라스트 공정'),
            ('PAINT', 6, '도장 공정'),
            ('PACKING', 7, '포장 공정')
        ]
        
        for process_name, order, desc in process_data:
            cursor.execute("""
                INSERT IGNORE INTO process_definitions (process_name, process_order, description)
                VALUES (%s, %s, %s)
            """, (process_name, order, desc))
        
        print("✅ 공정 정의 데이터 삽입 완료")
        
        # 4. 변경사항 커밋
        conn.commit()
        
        # 5. 테이블 상태 확인
        print("\n4️⃣ 테이블 상태 확인...")
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print("📋 생성된 테이블:")
        for table in tables:
            table_name = list(table.values())[0]
            print(f"  - {table_name}")
            
            # 각 테이블의 레코드 수 확인
            cursor.execute(f"SELECT COUNT(*) as count FROM {table_name}")
            count = cursor.fetchone()['count']
            print(f"    레코드 수: {count}개")
        
        print("\n🎉 데이터베이스 테이블 생성 완료!")
        return True
        
    except Exception as e:
        print(f"❌ 테이블 생성 오류: {e}")
        if conn:
            conn.rollback()
        return False
        
    finally:
        if conn:
            conn.close()

def test_import_data():
    """데이터 임포트 테스트"""
    print("\n📊 데이터 임포트 테스트 시작...")
    try:
        # import_data.py 실행
        import subprocess
        result = subprocess.run(['python', 'import_data.py'], 
                              capture_output=True, text=True, cwd='E:\\DSHI_RPA\\APP')
        
        if result.returncode == 0:
            print("✅ 데이터 임포트 성공!")
            print(result.stdout)
        else:
            print("❌ 데이터 임포트 실패!")
            print(result.stderr)
            
    except Exception as e:
        print(f"❌ 데이터 임포트 테스트 오류: {e}")

if __name__ == "__main__":
    print("🚀 DSHI 현장 패드 앱 데이터베이스 설정 시작...")
    print("=" * 60)
    
    # 1. 테이블 생성
    if create_tables():
        print("\n" + "=" * 60)
        # 2. 데이터 임포트 테스트
        test_import_data()
    else:
        print("❌ 테이블 생성 실패로 인해 프로세스를 중단합니다.")

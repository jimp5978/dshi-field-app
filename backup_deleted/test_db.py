import pymysql
from pymysql.cursors import DictCursor

# 데이터베이스 연결 테스트
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

try:
    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    print("✅ 데이터베이스 연결 성공!")
    
    # 테이블 목록 확인
    cursor.execute("SHOW TABLES;")
    tables = cursor.fetchall()
    print(f"\n📋 테이블 목록:")
    for table in tables:
        print(f"  - {list(table.values())[0]}")
    
    # assembly_items 테이블 구조 확인
    cursor.execute("DESCRIBE assembly_items;")
    columns = cursor.fetchall()
    print(f"\n🏗️ assembly_items 테이블 구조:")
    for col in columns:
        print(f"  - {col['Field']}: {col['Type']}")
    
    # 데이터 샘플 확인
    cursor.execute("SELECT COUNT(*) as total FROM assembly_items;")
    count = cursor.fetchone()
    print(f"\n📊 assembly_items 테이블 데이터 수: {count['total']}개")
    
    # 샘플 데이터 3개 확인
    cursor.execute("SELECT assembly_code, zone, item, fit_up_date, nde_date FROM assembly_items LIMIT 3;")
    samples = cursor.fetchall()
    print(f"\n📝 샘플 데이터:")
    for sample in samples:
        print(f"  - {sample['assembly_code']}: {sample['zone']}, {sample['item']}")
        print(f"    Fit-up: {sample['fit_up_date']}, NDE: {sample['nde_date']}")
    
    # process_definitions 테이블 확인
    cursor.execute("SELECT * FROM process_definitions ORDER BY process_order;")
    processes = cursor.fetchall()
    print(f"\n⚙️ 공정 정의:")
    for proc in processes:
        print(f"  {proc['process_order']}. {proc['process_name']}")
    
    conn.close()
    print("\n✅ 데이터베이스 테스트 완료!")
    
except Exception as e:
    print(f"❌ 데이터베이스 연결 오류: {e}")

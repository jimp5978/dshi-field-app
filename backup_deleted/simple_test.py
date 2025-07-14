# -*- coding: utf-8 -*-
import pymysql
from pymysql.cursors import DictCursor

# 데이터베이스 연결 테스트
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

try:
    conn = pymysql.connect(**DB_CONFIG)
    cursor = conn.cursor()
    
    print("DB 연결 성공!")
    
    # 테이블 목록 확인
    cursor.execute("SHOW TABLES;")
    tables = cursor.fetchall()
    print(f"테이블 목록:")
    for table in tables:
        print(f"  - {list(table.values())[0]}")
    
    # assembly_items 데이터 수 확인
    cursor.execute("SELECT COUNT(*) as total FROM assembly_items;")
    count = cursor.fetchone()
    print(f"assembly_items 데이터 수: {count['total']}개")
    
    # 샘플 데이터 확인
    cursor.execute("SELECT assembly_code, zone, item FROM assembly_items LIMIT 3;")
    samples = cursor.fetchall()
    print(f"샘플 데이터:")
    for sample in samples:
        print(f"  - {sample['assembly_code']}: {sample['zone']}, {sample['item']}")
    
    # 사용자 테이블 확인
    cursor.execute("SELECT username, full_name, permission_level FROM users LIMIT 5;")
    users = cursor.fetchall()
    print(f"사용자 데이터:")
    for user in users:
        print(f"  - {user['username']}: {user['full_name']} (Level {user['permission_level']})")
    
    conn.close()
    print("DB 테스트 완료!")
    
except Exception as e:
    print(f"DB 연결 오류: {e}")

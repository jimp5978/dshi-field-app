# -*- coding: utf-8 -*-
"""
DSHI Field Pad MySQL 연결 테스트
기존 MySQL 데이터베이스 연결 및 데이터 확인
"""
import pymysql
from pymysql.cursors import DictCursor
import pandas as pd
from datetime import datetime

# MySQL 연결 설정 (import_data.py와 동일)
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

def test_database_connection():
    """데이터베이스 연결 및 데이터 확인"""
    print("=" * 60)
    print("DSHI Field Pad MySQL 데이터베이스 연결 테스트")
    print("=" * 60)
    
    try:
        # MySQL 연결
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        print("✅ MySQL 데이터베이스 연결 성공!")
        
        # 1. 테이블 목록 확인
        cursor.execute("SHOW TABLES")
        tables = cursor.fetchall()
        print(f"\n📋 데이터베이스 테이블 목록:")
        for table in tables:
            table_name = list(table.values())[0]
            print(f"  - {table_name}")
        
        # 2. assembly_items 테이블 구조 확인
        cursor.execute("DESCRIBE assembly_items")
        columns = cursor.fetchall()
        print(f"\n🏗️ assembly_items 테이블 구조:")
        for col in columns:
            print(f"  - {col['Field']}: {col['Type']} {'(PK)' if col['Key'] == 'PRI' else ''}")
        
        # 3. 데이터 수 확인
        cursor.execute("SELECT COUNT(*) as total_count FROM assembly_items")
        count_result = cursor.fetchone()
        total_count = count_result['total_count']
        print(f"\n📊 assembly_items 테이블 데이터 수: {total_count}개")
        
        # 4. 샘플 데이터 확인 (상위 5개)
        cursor.execute("""
            SELECT assembly_code, zone, item, 
                   fit_up_date, nde_date, vidi_date, galv_date, 
                   shot_date, paint_date, packing_date
            FROM assembly_items 
            ORDER BY assembly_code 
            LIMIT 5
        """)
        sample_data = cursor.fetchall()
        print(f"\n📝 샘플 데이터 (상위 5개):")
        for i, row in enumerate(sample_data, 1):
            print(f"  {i}. {row['assembly_code']}")
            print(f"     Zone: {row['zone']}, Item: {row['item']}")
            
            # 공정 진행 상황 체크
            processes = ['fit_up_date', 'nde_date', 'vidi_date', 'galv_date', 'shot_date', 'paint_date', 'packing_date']
            process_names = ['Fit-up', 'NDE', 'VIDI', 'GALV', 'SHOT', 'PAINT', 'PACKING']
            completed_processes = []
            
            for j, process in enumerate(processes):
                if row[process] is not None:
                    completed_processes.append(process_names[j])
            
            if completed_processes:
                print(f"     완료된 공정: {', '.join(completed_processes)}")
            else:
                print(f"     완료된 공정: 없음")
            print()
        
        # 5. 공정별 완료 통계
        print(f"📈 공정별 완료 통계:")
        processes = ['fit_up_date', 'nde_date', 'vidi_date', 'galv_date', 'shot_date', 'paint_date', 'packing_date']
        process_names = ['Fit-up', 'NDE', 'VIDI', 'GALV', 'SHOT', 'PAINT', 'PACKING']
        
        for i, process in enumerate(processes):
            cursor.execute(f"SELECT COUNT(*) as completed FROM assembly_items WHERE {process} IS NOT NULL")
            completed = cursor.fetchone()['completed']
            percentage = (completed / total_count * 100) if total_count > 0 else 0
            print(f"  - {process_names[i]}: {completed}/{total_count} ({percentage:.1f}%)")
        
        # 6. 사용자 테이블 확인 (있다면)
        try:
            cursor.execute("SELECT COUNT(*) as user_count FROM users")
            user_count = cursor.fetchone()['user_count']
            print(f"\n👤 사용자 테이블 데이터 수: {user_count}개")
            
            if user_count > 0:
                cursor.execute("SELECT username, full_name, permission_level FROM users ORDER BY permission_level DESC LIMIT 5")
                users = cursor.fetchall()
                print(f"   샘플 사용자:")
                for user in users:
                    print(f"     - {user['username']}: {user['full_name']} (Level {user['permission_level']})")
        except pymysql.Error:
            print(f"\n👤 사용자 테이블: 아직 생성되지 않음")
        
        conn.close()
        return True
        
    except pymysql.Error as e:
        print(f"❌ MySQL 연결 오류: {e}")
        print("\n🔧 해결 방법:")
        print("1. MySQL 서버가 실행 중인지 확인")
        print("2. 사용자 계정 및 비밀번호 확인")
        print("3. 데이터베이스 'field_app_db'가 존재하는지 확인")
        return False
    except Exception as e:
        print(f"❌ 예상치 못한 오류: {e}")
        return False

def create_test_users():
    """테스트 사용자 생성"""
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        # users 테이블이 있는지 확인하고, 없으면 생성
        cursor.execute("SHOW TABLES LIKE 'users'")
        if not cursor.fetchone():
            print("\n👤 사용자 테이블 생성 중...")
            cursor.execute("""
                CREATE TABLE users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    password_hash VARCHAR(255) NOT NULL,
                    full_name VARCHAR(100) NOT NULL,
                    permission_level INT NOT NULL DEFAULT 1,
                    is_active BOOLEAN DEFAULT TRUE,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
            """)
            print("✅ 사용자 테이블 생성 완료!")
        
        # 테스트 사용자 데이터
        test_users = [
            ('admin', 'admin123', '시스템 관리자', 5),
            ('test_level1', 'test123', '외부업체 직원', 1),
            ('test_level2', 'test123', '외부업체 관리자', 2),
            ('test_level3', 'test123', 'DSHI 현장직원', 3),
            ('test_level4', 'test123', 'DSHI 관리직원', 4),
            ('test_level5', 'test123', 'DSHI 시스템관리', 5)
        ]
        
        print("\n👤 테스트 사용자 생성 중...")
        for username, password, full_name, level in test_users:
            try:
                cursor.execute("""
                    INSERT INTO users (username, password_hash, full_name, permission_level)
                    VALUES (%s, %s, %s, %s)
                    ON DUPLICATE KEY UPDATE
                    password_hash = VALUES(password_hash),
                    full_name = VALUES(full_name),
                    permission_level = VALUES(permission_level)
                """, (username, password, full_name, level))
                print(f"  ✅ {username}: {full_name} (Level {level})")
            except Exception as e:
                print(f"  ⚠️ {username}: 이미 존재하거나 오류 ({e})")
        
        conn.commit()
        conn.close()
        print("✅ 테스트 사용자 생성 완료!")
        return True
        
    except Exception as e:
        print(f"❌ 사용자 생성 오류: {e}")
        return False

if __name__ == "__main__":
    # 데이터베이스 연결 및 데이터 확인
    if test_database_connection():
        print("\n" + "=" * 60)
        
        # 테스트 사용자 생성
        if create_test_users():
            print("\n🎉 MySQL 데이터베이스 테스트 완료!")
            print("\n📝 테스트 결과:")
            print("  ✅ MySQL 연결 성공")
            print("  ✅ assembly_items 테이블 데이터 확인")
            print("  ✅ 테스트 사용자 생성")
            print("\n🚀 이제 Flask 서버와 Flutter 앱을 테스트할 수 있습니다!")
        else:
            print("\n⚠️ 사용자 생성에 실패했지만 데이터베이스는 정상입니다.")
    else:
        print("\n❌ MySQL 데이터베이스 연결에 실패했습니다.")
        print("SQLite 버전을 사용하거나 MySQL 설정을 확인해주세요.")

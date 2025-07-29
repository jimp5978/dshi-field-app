#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""import_data.py와 동일한 설정으로 MySQL 연결 테스트"""

import pymysql
import pymysql.cursors
from config_env import get_db_config

def test_import_db_connection():
    """import_data.py와 동일한 방식으로 연결 테스트"""
    try:
        DB_CONFIG = get_db_config()
        print(f"데이터베이스 설정: {DB_CONFIG}")
        
        print("PyMySQL로 연결 시도 중...")
        connection = pymysql.connect(**DB_CONFIG)
        
        print("[성공] 데이터베이스 연결 성공!")
        
        with connection.cursor(pymysql.cursors.DictCursor) as cursor:
            # 데이터베이스 정보 확인
            cursor.execute("SELECT DATABASE(), VERSION()")
            db_info = cursor.fetchone()
            print(f"[정보] 현재 데이터베이스: {db_info[list(db_info.keys())[0]]}")
            print(f"[정보] MySQL 버전: {db_info[list(db_info.keys())[1]]}")
            
            # 테이블 목록 확인
            cursor.execute("SHOW TABLES")
            tables = cursor.fetchall()
            print(f"[정보] 테이블 목록:")
            for table in tables:
                table_name = table[list(table.keys())[0]]
                print(f"  - {table_name}")
            
            # users 테이블 확인
            cursor.execute("SHOW TABLES LIKE 'users'")
            users_table = cursor.fetchone()
            
            if users_table:
                print("[성공] users 테이블 발견!")
                
                cursor.execute("SELECT COUNT(*) as count FROM users")
                user_count = cursor.fetchone()['count']
                print(f"[정보] users 테이블에 {user_count}개 레코드 존재")
                
                if user_count > 0:
                    cursor.execute("SELECT username, permission_level, full_name FROM users LIMIT 5")
                    users = cursor.fetchall()
                    print("[정보] 사용자 목록:")
                    for user in users:
                        print(f"  - {user['username']} (Level {user['permission_level']}) - {user['full_name']}")
            else:
                print("[경고] users 테이블이 없습니다")
            
            # arup_ecs 테이블 확인 (조립품 데이터)
            cursor.execute("SHOW TABLES LIKE 'arup_ecs'")
            arup_table = cursor.fetchone()
            
            if arup_table:
                print("[성공] arup_ecs 테이블 발견!")
                
                cursor.execute("SELECT COUNT(*) as count FROM arup_ecs")
                assembly_count = cursor.fetchone()['count']
                print(f"[정보] arup_ecs 테이블에 {assembly_count}개 조립품 데이터 존재")
                
                if assembly_count > 0:
                    cursor.execute("SELECT assembly_code, company, zone, item FROM arup_ecs LIMIT 3")
                    assemblies = cursor.fetchall()
                    print("[정보] 샘플 조립품:")
                    for assembly in assemblies:
                        print(f"  - {assembly['assembly_code']} | {assembly['company']} | {assembly['zone']} | {assembly['item']}")
            else:
                print("[경고] arup_ecs 테이블이 없습니다")
        
        connection.close()
        return True
        
    except Exception as e:
        print(f"[오류] 연결 실패: {e}")
        return False

if __name__ == "__main__":
    print("import_data.py 설정으로 MySQL 연결 테스트...")
    print("=" * 50)
    
    if test_import_db_connection():
        print("\n[성공] MySQL 연결 및 데이터베이스 상태 확인 완료!")
        print("Flask API와 Sinatra 웹 애플리케이션이 정상 작동할 것입니다.")
    else:
        print("\n[실패] MySQL 연결 실패")
        print("데이터베이스 설정을 확인하거나 MySQL 서비스를 시작하세요.")
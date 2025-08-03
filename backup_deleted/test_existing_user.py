#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""기존 사용자 계정으로 MySQL 연결 테스트"""

import mysql.connector
from mysql.connector import Error

# 기존 애플리케이션 사용자로 테스트
EXISTING_CONFIGS = [
    {"host": "localhost", "port": 3306, "user": "field_app_user", "password": "", "database": "field_app_db"},
    {"host": "localhost", "port": 3306, "user": "field_app_user", "password": "field_app_password", "database": "field_app_db"},
    {"host": "127.0.0.1", "port": 3306, "user": "field_app_user", "password": "", "database": "field_app_db"},
]

def test_existing_connection(config):
    """기존 사용자 연결 테스트"""
    try:
        print(f"테스트: {config['user']}@{config['host']} -> {config.get('database', 'no_db')}")
        connection = mysql.connector.connect(**config)
        
        cursor = connection.cursor()
        
        # users 테이블 확인
        cursor.execute("SHOW TABLES LIKE 'users'")
        users_table = cursor.fetchone()
        
        if users_table:
            print("[성공] users 테이블 발견!")
            
            # 사용자 수 확인
            cursor.execute("SELECT COUNT(*) FROM users")
            user_count = cursor.fetchone()[0]
            print(f"[정보] users 테이블에 {user_count}개 레코드 존재")
            
            # 샘플 사용자 확인
            cursor.execute("SELECT username, permission_level FROM users LIMIT 5")
            users = cursor.fetchall()
            print("[정보] 기존 사용자 목록:")
            for username, level in users:
                print(f"  - {username} (Level {level})")
                
            cursor.close()
            connection.close()
            return True
        else:
            print("[정보] users 테이블이 없습니다")
            
    except Error as e:
        print(f"[실패] {e}")
        return False

def main():
    print("기존 MySQL 사용자 계정 테스트...")
    print("=" * 50)
    
    for i, config in enumerate(EXISTING_CONFIGS, 1):
        print(f"\n{i}. 연결 시도:")
        if test_existing_connection(config):
            print(f"[성공] 이 설정으로 데이터베이스에 접근 가능: {config}")
            return config
        print("-" * 30)
    
    print("\n[실패] 모든 기존 사용자 연결 시도 실패")
    return None

if __name__ == "__main__":
    working_config = main()
    if working_config:
        print(f"\n사용 가능한 설정: {working_config}")
    else:
        print("\nMySQL root 비밀번호가 필요합니다.")
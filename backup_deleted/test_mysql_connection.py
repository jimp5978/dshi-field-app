#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MySQL 연결 테스트 스크립트"""

import mysql.connector
from mysql.connector import Error

# 다양한 MySQL 접속 설정을 시도
MYSQL_CONFIGS = [
    {"host": "localhost", "port": 3306, "user": "root", "password": ""},
    {"host": "localhost", "port": 3306, "user": "root", "password": "root"},
    {"host": "localhost", "port": 3306, "user": "root", "password": "admin"},
    {"host": "localhost", "port": 3306, "user": "root", "password": "mysql"},
    {"host": "127.0.0.1", "port": 3306, "user": "root", "password": ""},
    {"host": "127.0.0.1", "port": 3306, "user": "root", "password": "root"},
]

def test_connection(config):
    """MySQL 연결 테스트"""
    try:
        print(f"테스트 중: {config['user']}@{config['host']}:{config['port']} (password={'설정됨' if config['password'] else '없음'})")
        connection = mysql.connector.connect(**config)
        
        cursor = connection.cursor()
        cursor.execute("SELECT VERSION()")
        version = cursor.fetchone()[0]
        
        cursor.execute("SHOW DATABASES")
        databases = [db[0] for db in cursor.fetchall()]
        
        print(f"[성공] MySQL 버전: {version}")
        print(f"[성공] 사용 가능한 데이터베이스: {', '.join(databases)}")
        
        cursor.close()
        connection.close()
        return True
        
    except Error as e:
        print(f"[실패] 연결 오류: {e}")
        return False

def main():
    print("MySQL 연결 테스트 시작...")
    print("=" * 50)
    
    for i, config in enumerate(MYSQL_CONFIGS, 1):
        print(f"\n{i}. 연결 시도:")
        if test_connection(config):
            print(f"[성공] 이 설정으로 연결할 수 있습니다: {config}")
            return config
        print("-" * 30)
    
    print("\n[실패] 모든 연결 시도가 실패했습니다.")
    print("MySQL 서버가 실행 중이고 접근 권한이 있는지 확인하세요.")
    return None

if __name__ == "__main__":
    working_config = main()
    if working_config:
        print(f"\n사용할 수 있는 설정: {working_config}")
    else:
        print("\nMySQL 연결 설정을 수동으로 확인하세요.")
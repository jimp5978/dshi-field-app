#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""새 비밀번호로 MySQL 연결 테스트"""

import mysql.connector
from mysql.connector import Error

def test_new_password():
    """새 비밀번호로 연결 테스트"""
    try:
        config = {
            "host": "localhost",
            "port": 3306,
            "database": "field_app_db",
            "user": "field_app_user", 
            "password": "field_app_2024",
            "charset": "utf8mb4"
        }
        
        print(f"새 비밀번호로 연결 테스트: {config}")
        connection = mysql.connector.connect(**config)
        
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT 'MySQL 연결 성공!' as message, USER() as current_user")
        result = cursor.fetchone()
        
        print(f"[성공] {result['message']}")
        print(f"[정보] 현재 사용자: {result['current_user']}")
        
        cursor.close()
        connection.close()
        return True
        
    except Error as e:
        print(f"[실패] {e}")
        return False

if __name__ == "__main__":
    if test_new_password():
        print("\n✅ 새 비밀번호로 연결 성공!")
        print("config_env.py의 password를 'field_app_2024'로 업데이트하세요.")
    else:
        print("\n❌ 연결 실패")
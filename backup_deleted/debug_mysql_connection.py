#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""MySQL 연결 디버깅"""

import mysql.connector
from mysql.connector import Error
import pymysql
from config_env import get_db_config

def test_mysql_connector():
    """mysql-connector-python으로 연결 테스트"""
    print("=== mysql-connector-python 테스트 ===")
    try:
        DB_CONFIG = get_db_config()
        print(f"설정: {DB_CONFIG}")
        
        connection = mysql.connector.connect(**DB_CONFIG)
        
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT 'mysql-connector 연결 성공' as message")
        result = cursor.fetchone()
        print(f"[성공] {result['message']}")
        
        cursor.close()
        connection.close()
        return True
        
    except Error as e:
        print(f"[실패] mysql-connector-python: {e}")
        return False

def test_pymysql():
    """PyMySQL로 연결 테스트"""
    print("\n=== PyMySQL 테스트 ===")
    try:
        DB_CONFIG = get_db_config()
        print(f"설정: {DB_CONFIG}")
        
        connection = pymysql.connect(**DB_CONFIG)
        
        with connection.cursor(pymysql.cursors.DictCursor) as cursor:
            cursor.execute("SELECT 'PyMySQL 연결 성공' as message")
            result = cursor.fetchone()
            print(f"[성공] {result['message']}")
        
        connection.close()
        return True
        
    except Exception as e:
        print(f"[실패] PyMySQL: {e}")
        return False

def test_different_passwords():
    """다른 비밀번호들로 테스트"""
    print("\n=== 다양한 비밀번호 테스트 ===")
    
    passwords = ["", "field_app_password", "admin", "root", "mysql"]
    
    for password in passwords:
        try:
            config = {
                "host": "localhost",
                "port": 3306,
                "database": "field_app_db", 
                "user": "field_app_user",
                "password": password,
                "charset": "utf8mb4"
            }
            
            print(f"비밀번호 '{password}' 테스트 중...")
            connection = mysql.connector.connect(**config)
            
            cursor = connection.cursor()
            cursor.execute("SELECT 1")
            cursor.fetchone()
            
            print(f"[성공] 비밀번호: '{password}'")
            cursor.close()
            connection.close()
            return password
            
        except Error as e:
            print(f"[실패] 비밀번호 '{password}': {e}")
    
    return None

if __name__ == "__main__":
    print("MySQL 연결 디버깅 시작...")
    
    # 1. mysql-connector-python 테스트
    connector_success = test_mysql_connector()
    
    # 2. PyMySQL 테스트  
    pymysql_success = test_pymysql()
    
    # 3. 다양한 비밀번호 테스트
    if not connector_success and not pymysql_success:
        working_password = test_different_passwords()
        if working_password is not None:
            print(f"\n올바른 비밀번호를 찾았습니다: '{working_password}'")
            print("config_env.py에서 이 비밀번호로 수정하세요.")
    
    print("\n디버깅 완료")
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""로컬 MySQL 데이터베이스 초기화 스크립트"""

import mysql.connector
from mysql.connector import Error
import hashlib

# MySQL 루트 연결 설정 (처음 연결)
import getpass

ROOT_PASSWORD = ""  # 일반적으로 XAMPP에서는 root 비밀번호가 없음
ROOT_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "user": "root",
    "password": ROOT_PASSWORD,
    "charset": "utf8mb4"
}

# 애플리케이션 데이터베이스 설정
DB_CONFIG = {
    "host": "localhost",
    "port": 3306,
    "database": "field_app_db",
    "user": "field_app_user",
    "password": "",
    "charset": "utf8mb4"
}

def create_database_and_user():
    """데이터베이스와 사용자 생성"""
    try:
        # 루트로 연결
        connection = mysql.connector.connect(**ROOT_CONFIG)
        cursor = connection.cursor()
        
        # 데이터베이스 생성
        cursor.execute("CREATE DATABASE IF NOT EXISTS field_app_db")
        print("[OK] 데이터베이스 field_app_db 생성 완료")
        
        # 사용자 생성 (이미 존재하면 무시)
        try:
            cursor.execute("CREATE USER 'field_app_user'@'localhost'")
            print("[OK] 사용자 field_app_user 생성 완료")
        except mysql.connector.Error as e:
            if e.errno == 1396:  # User already exists
                print("[INFO] 사용자 field_app_user가 이미 존재합니다")
            else:
                raise
        
        # 권한 부여
        cursor.execute("GRANT ALL PRIVILEGES ON field_app_db.* TO 'field_app_user'@'localhost'")
        cursor.execute("FLUSH PRIVILEGES")
        print("[OK] 권한 설정 완료")
        
        cursor.close()
        connection.close()
        
    except Error as e:
        print(f"[ERROR] 데이터베이스 생성 오류: {e}")
        return False
    
    return True

def initialize_tables():
    """테이블 생성 및 초기 데이터 입력"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()
        
        # 사용자 테이블 생성
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS users (
                id INT PRIMARY KEY AUTO_INCREMENT,
                username VARCHAR(50) UNIQUE NOT NULL,
                password_hash VARCHAR(255) NOT NULL,
                permission_level INT DEFAULT 1,
                full_name VARCHAR(100),
                department VARCHAR(50),
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
            )
        """)
        print("[OK] users 테이블 생성 완료")
        
        # 검사신청 테이블 생성
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS inspection_requests (
                id INT PRIMARY KEY AUTO_INCREMENT,
                assembly_code VARCHAR(100) NOT NULL,
                inspection_type VARCHAR(50) NOT NULL,
                requester VARCHAR(100) NOT NULL,
                request_date DATE NOT NULL,
                status VARCHAR(20) DEFAULT 'pending',
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                INDEX idx_assembly_code (assembly_code),
                INDEX idx_status (status),
                INDEX idx_request_date (request_date)
            )
        """)
        print("[OK] inspection_requests 테이블 생성 완료")
        
        # 기본 사용자 생성 (비밀번호는 SHA-256으로 해시)
        admin_password = hashlib.sha256("admin123".encode()).hexdigest()
        
        users_to_insert = [
            ('admin', admin_password, 3, '시스템 관리자', 'IT'),
            ('inspector1', admin_password, 2, '검사원1', '품질관리'),
            ('user1', admin_password, 1, '일반사용자1', '생산'),
            ('user2', admin_password, 1, '일반사용자2', '생산')
        ]
        
        for username, password_hash, level, full_name, department in users_to_insert:
            cursor.execute("""
                INSERT IGNORE INTO users (username, password_hash, permission_level, full_name, department)
                VALUES (%s, %s, %s, %s, %s)
            """, (username, password_hash, level, full_name, department))
        
        print("[OK] 기본 사용자 계정 생성 완료")
        
        # 샘플 검사신청 데이터
        sample_requests = [
            ('ASM001', 'FIT_UP', 'user1', '2024-01-15', 'approved'),
            ('ASM002', 'FINAL', 'user2', '2024-01-16', 'pending'),
            ('ASM003', 'GALV', 'inspector1', '2024-01-17', 'confirmed')
        ]
        
        for assembly_code, inspection_type, requester, request_date, status in sample_requests:
            cursor.execute("""
                INSERT IGNORE INTO inspection_requests (assembly_code, inspection_type, requester, request_date, status)
                VALUES (%s, %s, %s, %s, %s)
            """, (assembly_code, inspection_type, requester, request_date, status))
        
        print("[OK] 샘플 검사신청 데이터 생성 완료")
        
        connection.commit()
        cursor.close()
        connection.close()
        
    except Error as e:
        print(f"[ERROR] 테이블 초기화 오류: {e}")
        return False
    
    return True

def test_connection():
    """데이터베이스 연결 테스트"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()
        
        cursor.execute("SELECT COUNT(*) FROM users")
        user_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM inspection_requests")
        request_count = cursor.fetchone()[0]
        
        print(f"[OK] 연결 테스트 성공: users={user_count}, inspection_requests={request_count}")
        
        cursor.close()
        connection.close()
        return True
        
    except Error as e:
        print(f"[ERROR] 연결 테스트 실패: {e}")
        return False

if __name__ == "__main__":
    print("DSHI Field Pad 로컬 데이터베이스 초기화 시작...")
    
    # 1. 데이터베이스와 사용자 생성
    if not create_database_and_user():
        print("[ERROR] 데이터베이스 생성 실패")
        exit(1)
    
    # 2. 테이블 생성 및 초기 데이터
    if not initialize_tables():
        print("[ERROR] 테이블 초기화 실패")
        exit(1)
    
    # 3. 연결 테스트
    if not test_connection():
        print("[ERROR] 연결 테스트 실패")
        exit(1)
    
    print("로컬 데이터베이스 초기화 완료!")
    print("기본 계정: admin/admin123 (Level 3)")
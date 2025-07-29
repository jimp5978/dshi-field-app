#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""SQLite를 이용한 임시 테스트 데이터베이스 생성"""

import sqlite3
import hashlib
from datetime import datetime

def create_sqlite_test_db():
    """SQLite 테스트 데이터베이스 생성"""
    try:
        # SQLite 데이터베이스 생성
        conn = sqlite3.connect('test_field_app.db')
        cursor = conn.cursor()
        
        # users 테이블 생성
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS users (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT UNIQUE NOT NULL,
                password_hash TEXT NOT NULL,
                permission_level INTEGER DEFAULT 1,
                full_name TEXT,
                department TEXT,
                is_active BOOLEAN DEFAULT 1,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # inspection_requests 테이블 생성
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS inspection_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                assembly_code TEXT NOT NULL,
                inspection_type TEXT NOT NULL,
                requester TEXT NOT NULL,
                request_date DATE NOT NULL,
                status TEXT DEFAULT 'pending',
                notes TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        # 기본 사용자 생성 (SHA-256 해시)
        admin_password = hashlib.sha256("admin123".encode()).hexdigest()
        
        users_to_insert = [
            ('admin', admin_password, 3, '시스템 관리자', 'IT'),
            ('inspector1', admin_password, 2, '검사원1', '품질관리'),
            ('user1', admin_password, 1, '일반사용자1', '생산'),
            ('user2', admin_password, 1, '일반사용자2', '생산')
        ]
        
        for username, password_hash, level, full_name, department in users_to_insert:
            cursor.execute('''
                INSERT OR IGNORE INTO users (username, password_hash, permission_level, full_name, department)
                VALUES (?, ?, ?, ?, ?)
            ''', (username, password_hash, level, full_name, department))
        
        # 샘플 검사신청 데이터
        sample_requests = [
            ('ASM001', 'FIT_UP', 'user1', '2024-01-15', 'approved'),
            ('ASM002', 'FINAL', 'user2', '2024-01-16', 'pending'),
            ('ASM003', 'GALV', 'inspector1', '2024-01-17', 'confirmed')
        ]
        
        for assembly_code, inspection_type, requester, request_date, status in sample_requests:
            cursor.execute('''
                INSERT OR IGNORE INTO inspection_requests (assembly_code, inspection_type, requester, request_date, status)
                VALUES (?, ?, ?, ?, ?)
            ''', (assembly_code, inspection_type, requester, request_date, status))
        
        conn.commit()
        
        # 생성된 데이터 확인
        cursor.execute("SELECT COUNT(*) FROM users")  
        user_count = cursor.fetchone()[0]
        
        cursor.execute("SELECT COUNT(*) FROM inspection_requests")
        request_count = cursor.fetchone()[0]
        
        print(f"[성공] SQLite 테스트 데이터베이스 생성 완료")
        print(f"[정보] users: {user_count}, inspection_requests: {request_count}")
        
        # 사용자 목록 출력
        cursor.execute("SELECT username, permission_level FROM users")
        users = cursor.fetchall()
        print("[정보] 생성된 사용자:")
        for username, level in users:
            print(f"  - {username} (Level {level})")
        
        conn.close()
        return True
        
    except Exception as e:
        print(f"[오류] SQLite 데이터베이스 생성 실패: {e}")
        return False

if __name__ == "__main__":
    print("SQLite 임시 테스트 데이터베이스 생성...")
    if create_sqlite_test_db():
        print("\n테스트용 SQLite 데이터베이스가 'test_field_app.db'에 생성되었습니다.")
        print("기본 계정: admin/admin123 (Level 3)")
    else:
        print("데이터베이스 생성에 실패했습니다.")
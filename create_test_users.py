#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pymysql
import hashlib
from datetime import datetime
import sys

# 데이터베이스 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'database': 'field_app_db',
    'charset': 'utf8mb4'
}

def get_db_connection():
    """MySQL 데이터베이스 연결"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        return connection
    except Exception as e:
        print(f"데이터베이스 연결 오류: {e}")
        return None

def hash_password(password):
    """SHA256으로 비밀번호 해시화 (Flutter AuthService와 동일)"""
    return hashlib.sha256(password.encode()).hexdigest()

def create_test_users():
    """테스트 사용자 계정 생성"""
    try:
        print("=== DSHI Field Pad 테스트 사용자 생성 ===")
        
        # 테스트 사용자 정의
        test_users = [
            {
                'username': 'a',
                'password': 'a',
                'full_name': 'Administrator',
                'permission_level': 5,  # Admin (Level 5로 변경)
                'description': '시스템 관리자'
            },
            {
                'username': 'l1',
                'password': 'l1',
                'full_name': 'Level 1 User',
                'permission_level': 1,  # 외부업체
                'description': '외부업체 (검색, LIST UP, 검사신청)'
            },
            {
                'username': 'l2',
                'password': 'l2',
                'full_name': 'Level 2 User',
                'permission_level': 2,  # 미사용
                'description': '미사용 레벨'
            },
            {
                'username': 'l3',
                'password': 'l3',
                'full_name': 'Level 3 User',
                'permission_level': 3,  # DSHI 현장직원
                'description': 'DSHI 현장직원 (롤백, PDF, 업로드 기능)'
            },
            {
                'username': 'l4',
                'password': 'l4',
                'full_name': 'Level 4 User',
                'permission_level': 4,  # DSHI 관리직원
                'description': 'DSHI 관리직원'
            },
            {
                'username': 'l5',
                'password': 'l5',
                'full_name': 'Level 5 User',
                'permission_level': 5,  # DSHI 관리직원
                'description': 'DSHI 관리직원'
            }
        ]
        
        connection = get_db_connection()
        if not connection:
            print("데이터베이스 연결 실패")
            return False
        
        try:
            with connection.cursor() as cursor:
                # users 테이블이 없으면 생성
                create_table_sql = """
                CREATE TABLE IF NOT EXISTS users (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    username VARCHAR(50) UNIQUE NOT NULL,
                    password_hash VARCHAR(64) NOT NULL,
                    full_name VARCHAR(100) NOT NULL,
                    permission_level INT NOT NULL DEFAULT 1,
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    is_active BOOLEAN DEFAULT TRUE,
                    INDEX idx_username (username),
                    INDEX idx_permission (permission_level)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
                """
                cursor.execute(create_table_sql)
                print("users 테이블 확인/생성 완료")
                
                # 기존 테스트 사용자 삭제
                test_usernames = [user['username'] for user in test_users]
                placeholders = ', '.join(['%s'] * len(test_usernames))
                cursor.execute(f"DELETE FROM users WHERE username IN ({placeholders})", test_usernames)
                print("기존 테스트 사용자 삭제 완료")
                
                # 새로운 테스트 사용자 생성
                created_count = 0
                for user in test_users:
                    try:
                        password_hash = hash_password(user['password'])
                        
                        sql = """
                        INSERT INTO users (
                            username, 
                            password_hash, 
                            full_name, 
                            permission_level,
                            created_at,
                            updated_at
                        ) VALUES (%s, %s, %s, %s, %s, %s)
                        """
                        
                        current_time = datetime.now()
                        cursor.execute(sql, (
                            user['username'],
                            password_hash,
                            user['full_name'],
                            user['permission_level'],
                            current_time,
                            current_time
                        ))
                        
                        created_count += 1
                        print(f"  ✅ {user['username']} ({user['full_name']}) - Level {user['permission_level']}")
                        
                    except Exception as e:
                        print(f"  ❌ {user['username']} 생성 실패: {e}")
                        continue
                
                # 커밋
                connection.commit()
                
                print(f"\n=== 테스트 사용자 생성 완료 ===")
                print(f"총 {created_count}개 계정 생성")
                
                # 생성된 사용자 확인
                print("\n=== 생성된 사용자 목록 ===")
                cursor.execute("""
                    SELECT username, full_name, permission_level 
                    FROM users 
                    ORDER BY permission_level DESC
                """)
                users = cursor.fetchall()
                
                for user in users:
                    print(f"  {user[0]} / {user[0]} - "
                          f"{user[1]} (Level {user[2]})")
                
                print(f"\n총 {len(users)}개 사용자 계정 존재")
                
                return True
                
        finally:
            connection.close()
            
    except Exception as e:
        print(f"테스트 사용자 생성 오류: {e}")
        return False

def verify_login(username, password):
    """로그인 테스트"""
    try:
        print(f"\n=== 로그인 테스트: {username} ===")
        
        password_hash = hash_password(password)
        
        connection = get_db_connection()
        if not connection:
            return False
        
        try:
            with connection.cursor() as cursor:
                sql = """
                SELECT id, username, full_name, permission_level, password_hash 
                FROM users 
                WHERE username = %s
                """
                cursor.execute(sql, (username,))
                user = cursor.fetchone()
                
                if user and user['password_hash'] == password_hash:
                    print(f"  ✅ 로그인 성공")
                    print(f"  사용자: {user['full_name']}")
                    print(f"  권한 레벨: {user['permission_level']}")
                    return True
                else:
                    print(f"  ❌ 로그인 실패")
                    return False
                    
        finally:
            connection.close()
            
    except Exception as e:
        print(f"  ❌ 로그인 테스트 오류: {e}")
        return False

if __name__ == '__main__':
    print("DSHI Field Pad 테스트 사용자 생성 스크립트")
    
    # 테스트 사용자 생성
    success = create_test_users()
    
    if success:
        print("\n" + "="*50)
        print("테스트 로그인 계정 정보:")
        print("="*50)
        print("Admin:    a / a")
        print("Level 1:  l1 / l1")
        print("Level 2:  l2 / l2")
        print("Level 3:  l3 / l3")
        print("Level 4:  l4 / l4")
        print("Level 5:  l5 / l5")
        print("="*50)
        
        # 로그인 테스트 수행
        if len(sys.argv) > 1 and sys.argv[1] == 'test':
            print("\n로그인 테스트 수행...")
            test_accounts = ['a', 'l1', 'l3']
            for username in test_accounts:
                verify_login(username, username)
        
        print("\n✅ 작업 완료")
    else:
        print("\n❌ 작업 실패")
        sys.exit(1)
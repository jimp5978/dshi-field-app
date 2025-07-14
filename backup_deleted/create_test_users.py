# -*- coding: utf-8 -*-
import pymysql
from pymysql.cursors import DictCursor
import hashlib

DB_CONFIG = {
    'host': 'localhost',
    'user': 'field_app_user',
    'password': 'F!eldApp_Pa$$w0rd_2025#',
    'db': 'field_app_db',
    'charset': 'utf8mb4',
    'cursorclass': DictCursor
}

def create_test_users():
    conn = None
    try:
        conn = pymysql.connect(**DB_CONFIG)
        cursor = conn.cursor()
        
        print("Creating test users...")
        
        # 새로운 간단한 테스트 계정
        test_users = [
            {
                'username': 'a',
                'password': 'a',
                'full_name': 'Admin User',
                'permission_level': 5,
                'type': 'dshi',
                'department': 'System Admin'
            },
            {
                'username': 'l1',
                'password': 'l1',
                'full_name': 'Level1 User',
                'permission_level': 1,
                'type': 'external',
                'company_name': 'ABC Company'
            },
            {
                'username': 'l2', 
                'password': 'l2',
                'full_name': 'Level2 User',
                'permission_level': 2,
                'type': 'external',
                'company_name': 'XYZ Partners'
            },
            {
                'username': 'l3',
                'password': 'l3', 
                'full_name': 'Level3 User',
                'permission_level': 3,
                'type': 'dshi',
                'department': 'Field Management'
            },
            {
                'username': 'l4',
                'password': 'l4',
                'full_name': 'Level4 User', 
                'permission_level': 4,
                'type': 'dshi',
                'department': 'Quality Control'
            },
            {
                'username': 'l5',
                'password': 'l5',
                'full_name': 'Level5 User',
                'permission_level': 5,
                'type': 'dshi',
                'department': 'System Admin'
            }
        ]
        
        # 기존 계정 유지 (호환성을 위해)
        legacy_users = [
            {
                'username': 'admin',
                'password': 'admin123',
                'full_name': 'Administrator',
                'permission_level': 5,
                'type': 'dshi',
                'department': 'System Admin'
            },
            {
                'username': 'test_level1',
                'password': 'test123',
                'full_name': 'Test Level1 User',
                'permission_level': 1,
                'type': 'external',
                'company_name': 'ABC Company'
            },
            {
                'username': 'test_level2', 
                'password': 'test123',
                'full_name': 'Test Level2 User',
                'permission_level': 2,
                'type': 'external',
                'company_name': 'XYZ Partners'
            },
            {
                'username': 'test_level3',
                'password': 'test123', 
                'full_name': 'Test Level3 User',
                'permission_level': 3,
                'type': 'dshi',
                'department': 'Field Management'
            },
            {
                'username': 'test_level4',
                'password': 'test123',
                'full_name': 'Test Level4 User', 
                'permission_level': 4,
                'type': 'dshi',
                'department': 'Quality Control'
            },
            {
                'username': 'test_level5',
                'password': 'test123',
                'full_name': 'Test Level5 User',
                'permission_level': 5,
                'type': 'dshi',
                'department': 'System Admin'
            }
        ]
        
        # 모든 사용자 생성
        all_users = test_users + legacy_users
        created_count = 0
        
        for user in all_users:
            try:
                password_hash = hashlib.sha256(user['password'].encode()).hexdigest()
                
                cursor.execute("""
                    INSERT IGNORE INTO users (username, password_hash, full_name, permission_level)
                    VALUES (%s, %s, %s, %s)
                """, (user['username'], password_hash, user['full_name'], user['permission_level']))
                
                if cursor.rowcount > 0:
                    cursor.execute("SELECT id FROM users WHERE username = %s", (user['username'],))
                    user_result = cursor.fetchone()
                    user_id = user_result['id']
                    
                    if user['type'] == 'dshi':
                        cursor.execute("""
                            INSERT IGNORE INTO dshi_staff (user_id, department)
                            VALUES (%s, %s)
                        """, (user_id, user['department']))
                    else:
                        cursor.execute("""
                            INSERT IGNORE INTO external_users (user_id, company_name)
                            VALUES (%s, %s)
                        """, (user_id, user['company_name']))
                    
                    created_count += 1
                    print(f"Created: {user['username']} ({user['full_name']}, Level {user['permission_level']})")
                else:
                    print(f"Already exists: {user['username']}")
                    
            except Exception as user_error:
                print(f"Failed to create {user['username']}: {user_error}")
        
        conn.commit()
        
        print(f"\nTest users created: {created_count}")
        print("\n=== NEW Simple Test Accounts ===")
        print("Admin:    a / a")
        print("Level 1:  l1 / l1  (외부업체)")
        print("Level 2:  l2 / l2  (미사용)")
        print("Level 3:  l3 / l3  (DSHI 현장직원)")
        print("Level 4:  l4 / l4  (DSHI 관리직원)")
        print("Level 5:  l5 / l5  (DSHI 시스템관리자)")
        print("\n=== Legacy Test Accounts (기존 호환) ===")
        print("Admin: admin / admin123")
        print("Level 1-5: test_level1~5 / test123")
        print("================================")
        
        return True
        
    except Exception as e:
        print(f"Error creating test users: {e}")
        if conn:
            conn.rollback()
        return False
        
    finally:
        if conn:
            conn.close()

if __name__ == "__main__":
    print("DSHI Field Pad App - Create Test Users")
    print("=" * 50)
    
    if create_test_users():
        print("\nTest users creation completed!")
    else:
        print("Test users creation failed")

#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import mysql.connector
from config_env import get_db_config

def create_user_saved_lists_table():
    """사용자별 저장된 리스트 테이블 생성"""
    try:
        # 데이터베이스 연결
        db_config = get_db_config()
        connection = mysql.connector.connect(**db_config)
        cursor = connection.cursor()
        
        print("MySQL 연결 성공!")
        
        # 테이블 생성 SQL
        create_table_sql = """
        CREATE TABLE IF NOT EXISTS user_saved_lists (
            id INT PRIMARY KEY AUTO_INCREMENT,
            user_id INT NOT NULL,
            assembly_code VARCHAR(100) NOT NULL,
            assembly_data JSON NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
            UNIQUE KEY unique_user_assembly (user_id, assembly_code),
            INDEX idx_user_id (user_id),
            INDEX idx_assembly_code (assembly_code)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        """
        
        cursor.execute(create_table_sql)
        print("user_saved_lists 테이블 생성 완료!")
        
        # 테이블 확인
        cursor.execute("SHOW TABLES LIKE 'user_saved_lists'")
        result = cursor.fetchone()
        if result:
            print("테이블 존재 확인됨")
            
            # 테이블 구조 확인
            cursor.execute("DESCRIBE user_saved_lists")
            columns = cursor.fetchall()
            print("\n테이블 구조:")
            for column in columns:
                print(f"  - {column[0]}: {column[1]} {column[2]} {column[3]} {column[4]}")
        else:
            print("테이블 생성 실패")
        
        connection.commit()
        
    except mysql.connector.Error as e:
        print(f"❌ MySQL 오류: {e}")
        
    except Exception as e:
        print(f"❌ 일반 오류: {e}")
        
    finally:
        if 'connection' in locals() and connection.is_connected():
            cursor.close()
            connection.close()
            print("🔌 MySQL 연결 종료")

if __name__ == "__main__":
    create_user_saved_lists_table()
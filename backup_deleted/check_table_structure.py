#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inspection_requests 테이블의 전체 구조 확인 스크립트
"""

import mysql.connector
from config_env import DATABASE_CONFIG

def main():
    try:
        # 데이터베이스 연결
        conn = mysql.connector.connect(**DATABASE_CONFIG)
        cursor = conn.cursor()
        
        print("=== inspection_requests 테이블 구조 ===\n")
        
        # 테이블 구조 상세 조회
        cursor.execute("DESCRIBE inspection_requests")
        results = cursor.fetchall()
        
        print(f"{'컬럼명':<25} {'타입':<20} {'NULL':<8} {'키':<8} {'기본값':<15} {'추가정보'}")
        print("-" * 90)
        
        for row in results:
            field = row[0]
            type_info = row[1]
            null_info = row[2]
            key_info = row[3]
            default_info = str(row[4]) if row[4] is not None else 'None'
            extra_info = row[5]
            
            print(f"{field:<25} {type_info:<20} {null_info:<8} {key_info:<8} {default_info:<15} {extra_info}")
        
        print(f"\n총 {len(results)}개의 컬럼이 있습니다.")
        
        # 인덱스 정보 조회
        print("\n=== 인덱스 정보 ===\n")
        cursor.execute(f"""
            SELECT index_name, column_name, index_type
            FROM information_schema.STATISTICS 
            WHERE table_name = 'inspection_requests' 
            AND table_schema = '{DATABASE_CONFIG['database']}'
            ORDER BY index_name, seq_in_index
        """)
        
        index_results = cursor.fetchall()
        if index_results:
            current_index = None
            for row in index_results:
                index_name = row[0]
                column_name = row[1]
                index_type = row[2]
                
                if current_index != index_name:
                    print(f"{index_name} ({index_type}): {column_name}")
                    current_index = index_name
                else:
                    print(f"{'':>20} {column_name}")
        
        # 외래키 제약조건 조회
        print("\n=== 외래키 제약조건 ===\n")
        cursor.execute(f"""
            SELECT CONSTRAINT_NAME, COLUMN_NAME, REFERENCED_TABLE_NAME, REFERENCED_COLUMN_NAME
            FROM information_schema.KEY_COLUMN_USAGE
            WHERE table_name = 'inspection_requests' 
            AND table_schema = '{DATABASE_CONFIG['database']}'
            AND REFERENCED_TABLE_NAME IS NOT NULL
        """)
        
        fk_results = cursor.fetchall()
        if fk_results:
            for row in fk_results:
                constraint_name = row[0]
                column_name = row[1]
                ref_table = row[2]
                ref_column = row[3]
                print(f"{constraint_name}: {column_name} -> {ref_table}.{ref_column}")
        else:
            print("외래키 제약조건이 없습니다.")
        
    except mysql.connector.Error as e:
        print(f"데이터베이스 오류: {e}")
        
    except Exception as e:
        print(f"일반 오류: {e}")
        
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()

if __name__ == "__main__":
    main()
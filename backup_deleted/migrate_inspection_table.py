#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
inspection_requests 테이블에 승인자/확정자 정보 컬럼 추가하는 마이그레이션 스크립트
"""

import mysql.connector
from config_env import DATABASE_CONFIG

def main():
    try:
        # 데이터베이스 연결
        conn = mysql.connector.connect(**DATABASE_CONFIG)
        cursor = conn.cursor()
        
        print("데이터베이스 연결 성공")
        
        # 테이블 현재 구조 확인
        cursor.execute("DESCRIBE inspection_requests")
        columns = [row[0] for row in cursor.fetchall()]
        print(f"현재 컬럼: {columns}")
        
        # 추가할 컬럼들 정의
        new_columns = [
            ("approved_by", "INT"),
            ("approved_by_name", "VARCHAR(100)"),
            ("approved_date", "TIMESTAMP NULL"),
            ("confirmed_by", "INT"),  
            ("confirmed_by_name", "VARCHAR(100)"),
            ("confirmed_date", "TIMESTAMP NULL")
        ]
        
        # 각 컬럼 추가 (이미 존재하지 않는 경우만)
        for column_name, column_type in new_columns:
            if column_name not in columns:
                try:
                    sql = f"ALTER TABLE inspection_requests ADD COLUMN {column_name} {column_type}"
                    cursor.execute(sql)
                    print(f"컬럼 추가 성공: {column_name}")
                except mysql.connector.Error as e:
                    print(f"컬럼 추가 실패: {column_name} - {e}")
            else:
                print(f"컬럼 이미 존재: {column_name}")
        
        # 인덱스 추가
        indexes = [
            ("idx_approved_by", "approved_by"),
            ("idx_confirmed_by", "confirmed_by")
        ]
        
        for index_name, column_name in indexes:
            try:
                # 인덱스 존재 여부 확인
                cursor.execute(f"""
                    SELECT COUNT(*) FROM information_schema.STATISTICS 
                    WHERE table_name = 'inspection_requests' 
                    AND table_schema = '{DATABASE_CONFIG['database']}' 
                    AND index_name = '{index_name}'
                """)
                
                if cursor.fetchone()[0] == 0:
                    sql = f"CREATE INDEX {index_name} ON inspection_requests ({column_name})"
                    cursor.execute(sql)
                    print(f"인덱스 추가 성공: {index_name}")
                else:
                    print(f"인덱스 이미 존재: {index_name}")
                    
            except mysql.connector.Error as e:
                print(f"인덱스 추가 실패: {index_name} - {e}")
        
        # 변경사항 커밋
        conn.commit()
        
        # 최종 테이블 구조 확인
        cursor.execute("DESCRIBE inspection_requests")
        print("\n업데이트된 테이블 구조:")
        for row in cursor.fetchall():
            print(f"  {row[0]} - {row[1]} - {row[2]} - {row[3]} - {row[4]} - {row[5]}")
        
        print("\n마이그레이션 완료!")
        
    except mysql.connector.Error as e:
        print(f"데이터베이스 오류: {e}")
        return False
        
    except Exception as e:
        print(f"일반 오류: {e}")
        return False
        
    finally:
        if 'cursor' in locals():
            cursor.close()
        if 'conn' in locals():
            conn.close()
            print("데이터베이스 연결 종료")
    
    return True

if __name__ == "__main__":
    main()
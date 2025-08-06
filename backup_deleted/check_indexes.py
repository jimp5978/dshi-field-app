#!/usr/bin/env python3
"""
데이터베이스 인덱스 확인 및 최적화 스크립트
Phase 1.3: 대시보드 성능 최적화를 위한 인덱스 분석
"""

import mysql.connector
from config_env import get_db_config

def check_database_indexes():
    """현재 arup_ecs 테이블의 인덱스 상태 확인"""
    try:
        config = get_db_config()
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor(dictionary=True)
        
        print("=== ARUP_ECS 테이블 인덱스 현황 ===")
        
        # 현재 인덱스 확인
        cursor.execute("SHOW INDEX FROM arup_ecs")
        indexes = cursor.fetchall()
        
        print("\n현재 인덱스 목록:")
        for idx in indexes:
            print(f"- {idx['Key_name']}: {idx['Column_name']} (Cardinality: {idx['Cardinality']})")
        
        # 테이블 통계 확인
        cursor.execute("SELECT COUNT(*) as total_rows FROM arup_ecs")
        total_rows = cursor.fetchone()['total_rows']
        print(f"\n총 레코드 수: {total_rows:,}개")
        
        # 날짜 컬럼별 NULL/유효 데이터 분포 확인
        date_columns = [
            'fit_up_date', 'final_date', 'arup_final_date', 'galv_date',
            'arup_galv_date', 'shot_date', 'paint_date', 'arup_paint_date'
        ]
        
        print("\n=== 날짜 컬럼별 데이터 분포 ===")
        for col in date_columns:
            cursor.execute(f"""
                SELECT 
                    COUNT(*) as total,
                    COUNT({col}) as not_null,
                    SUM(CASE WHEN {col} IS NOT NULL AND {col} != '1900-01-01' THEN 1 ELSE 0 END) as valid_dates
                FROM arup_ecs
            """)
            result = cursor.fetchone()
            valid_pct = (result['valid_dates'] / result['total']) * 100
            print(f"- {col}: {result['valid_dates']:,}/{result['total']:,} ({valid_pct:.1f}%)")
        
        # 업체별, 아이템별 분포 확인
        print("\n=== 업체별 분포 ===")
        cursor.execute("""
            SELECT company, COUNT(*) as count, ROUND(COUNT(*) * 100.0 / %s, 1) as percentage
            FROM arup_ecs 
            WHERE company IS NOT NULL 
            GROUP BY company 
            ORDER BY count DESC
        """, (total_rows,))
        
        companies = cursor.fetchall()
        for comp in companies:
            print(f"- {comp['company']}: {comp['count']:,}개 ({comp['percentage']}%)")
        
        print("\n=== 아이템별 분포 ===")
        cursor.execute("""
            SELECT item, COUNT(*) as count, ROUND(COUNT(*) * 100.0 / %s, 1) as percentage
            FROM arup_ecs 
            WHERE item IS NOT NULL 
            GROUP BY item 
            ORDER BY count DESC
        """, (total_rows,))
        
        items = cursor.fetchall()
        for item in items:
            print(f"- {item['item']}: {item['count']:,}개 ({item['percentage']}%)")
        
        # 성능 향상을 위한 인덱스 추천
        print("\n=== 권장 인덱스 ===")
        recommend_indexes(cursor, indexes)
        
        cursor.close()
        connection.close()
        
    except Exception as e:
        print(f"오류 발생: {e}")

def recommend_indexes(cursor, existing_indexes):
    """성능 향상을 위한 인덱스 추천"""
    
    # 기존 인덱스 컬럼 목록
    existing_columns = set()
    for idx in existing_indexes:
        existing_columns.add(idx['Column_name'])
    
    recommendations = []
    
    # 1. weight_net 컬럼 인덱스 (필수)
    if 'weight_net' not in existing_columns:
        recommendations.append(("idx_weight_net", "weight_net", "필수 - 모든 대시보드 쿼리에서 사용"))
    
    # 2. 날짜 컬럼 복합 인덱스
    date_columns = ['fit_up_date', 'final_date', 'arup_final_date', 'galv_date', 
                   'arup_galv_date', 'shot_date', 'paint_date', 'arup_paint_date']
    
    missing_date_columns = [col for col in date_columns if col not in existing_columns]
    if missing_date_columns:
        recommendations.append(("idx_process_dates", ", ".join(date_columns[:4]), "8단계 공정 쿼리 최적화"))
    
    # 3. company 컬럼 인덱스
    if 'company' not in existing_columns:
        recommendations.append(("idx_company", "company", "업체별 분포 쿼리 최적화"))
    
    # 4. item 컬럼 인덱스  
    if 'item' not in existing_columns:
        recommendations.append(("idx_item", "item", "ITEM별 공정률 쿼리 최적화"))
    
    # 5. 복합 인덱스 권장
    recommendations.append(("idx_item_weight", "item, weight_net", "ITEM별 쿼리 최적화"))
    recommendations.append(("idx_company_weight", "company, weight_net", "업체별 쿼리 최적화"))
    
    if recommendations:
        print("다음 인덱스들을 추가하면 성능이 향상됩니다:")
        for idx_name, columns, description in recommendations:
            print(f"\n- CREATE INDEX {idx_name} ON arup_ecs({columns});")
            print(f"  → {description}")
    else:
        print("현재 인덱스 구성이 적절합니다.")

def create_recommended_indexes():
    """권장 인덱스 생성"""
    try:
        config = get_db_config()
        connection = mysql.connector.connect(**config)
        cursor = connection.cursor()
        
        # 권장 인덱스 생성 SQL
        index_queries = [
            "CREATE INDEX IF NOT EXISTS idx_weight_net ON arup_ecs(weight_net)",
            "CREATE INDEX IF NOT EXISTS idx_company ON arup_ecs(company)",
            "CREATE INDEX IF NOT EXISTS idx_item ON arup_ecs(item)",
            "CREATE INDEX IF NOT EXISTS idx_item_weight ON arup_ecs(item, weight_net)",
            "CREATE INDEX IF NOT EXISTS idx_company_weight ON arup_ecs(company, weight_net)",
            "CREATE INDEX IF NOT EXISTS idx_fit_up_date ON arup_ecs(fit_up_date)",
            "CREATE INDEX IF NOT EXISTS idx_arup_paint_date ON arup_ecs(arup_paint_date)"
        ]
        
        print("=== 인덱스 생성 시작 ===")
        for i, query in enumerate(index_queries, 1):
            try:
                print(f"[{i}/{len(index_queries)}] {query}")
                cursor.execute(query)
                print("✅ 성공")
            except Exception as e:
                print(f"❌ 실패: {e}")
        
        connection.commit()
        print("\n=== 인덱스 생성 완료 ===")
        
        cursor.close()
        connection.close()
        
    except Exception as e:
        print(f"인덱스 생성 오류: {e}")

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1 and sys.argv[1] == "create":
        create_recommended_indexes()
    else:
        check_database_indexes()
        print("\n인덱스를 생성하려면: python check_indexes.py create")
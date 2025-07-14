import sys
import os
sys.path.append('E:\\DSHI_RPA\\APP')

# Flask 앱 임포트 및 테스트
try:
    from app import app, get_db
    import json
    
    print("✅ Flask 앱 임포트 성공!")
    
    # 테스트 클라이언트 생성
    with app.test_client() as client:
        print("\n🔍 API 테스트 시작...")
        
        # 1. 검색 API 테스트
        print("\n1️⃣ 검색 API 테스트 (/api/search_assembly)")
        response = client.get('/api/search_assembly?query=test')
        print(f"   상태 코드: {response.status_code}")
        if response.status_code == 200:
            data = json.loads(response.data)
            print(f"   응답 데이터 수: {len(data)}개")
            if len(data) > 0:
                print(f"   첫 번째 결과: {data[0].get('ASSEMBLY', 'N/A')}")
        else:
            print(f"   오류: {response.data.decode()}")
        
        # 2. 특정 ASSEMBLY 검색 테스트 (실제 데이터가 있다면)
        print("\n2️⃣ 빈 검색 테스트")
        response = client.get('/api/search_assembly?query=')
        print(f"   상태 코드: {response.status_code}")
        
        # 3. 데이터베이스 직접 연결 테스트
        print("\n3️⃣ 데이터베이스 연결 테스트")
        try:
            conn = get_db()
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) as total FROM assembly_items")
            result = cursor.fetchone()
            print(f"   assembly_items 테이블 데이터 수: {result['total']}개")
            
            # 실제 데이터 몇 개 가져오기
            cursor.execute("SELECT assembly_code, zone, item FROM assembly_items LIMIT 5")
            samples = cursor.fetchall()
            print(f"   샘플 데이터:")
            for sample in samples:
                print(f"     - {sample['assembly_code']}: {sample['zone']}/{sample['item']}")
            
            conn.close()
            print("   ✅ 데이터베이스 연결 및 조회 성공!")
            
        except Exception as db_error:
            print(f"   ❌ 데이터베이스 오류: {db_error}")
    
    print("\n✅ Flask 서버 테스트 완료!")
    
except ImportError as e:
    print(f"❌ Flask 앱 임포트 오류: {e}")
except Exception as e:
    print(f"❌ 예상치 못한 오류: {e}")

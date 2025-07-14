import requests
import json

def test_specific_assembly():
    """특정 ASSEMBLY 테스트"""
    base_url = "http://localhost:5000"
    test_assembly = "RF-031-M2-SE-SD843"
    
    print(f"🔍 {test_assembly} 테스트 시작...")
    print("=" * 60)
    
    try:
        # 1. 특정 ASSEMBLY 검색
        url = f"{base_url}/api/search_assembly?query={test_assembly}"
        response = requests.get(url, timeout=5)
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ 검색 성공! 결과 수: {len(data)}개")
            
            if len(data) > 0:
                item = data[0]
                print("\n📊 상세 데이터:")
                print(f"  ASSEMBLY: {item.get('ASSEMBLY')}")
                print(f"  ZONE: {item.get('ZONE')}")
                print(f"  ITEM: {item.get('ITEM')}")
                print(f"  Fit-up_date: {item.get('Fit-up_date')}")
                print(f"  NDE_date: {item.get('NDE_date')}")
                print(f"  VIDI_date: {item.get('VIDI_date')}")
                print(f"  GALV_date: {item.get('GALV_date')}")
                print(f"  SHOT_date: {item.get('SHOT_date')}")
                print(f"  PAINT_date: {item.get('PAINT_date')}")
                print(f"  PACKING_date: {item.get('PACKING_date')}")
                print(f"  마지막 단계: {item.get('마지막 단계')}")
                print(f"  마지막 단계 날짜: {item.get('마지막 단계 날짜')}")
                
                # 2. 빈 검색으로 전체 데이터 확인
                print("\n🔍 빈 검색으로 다른 데이터들도 확인...")
                all_response = requests.get(f"{base_url}/api/search_assembly?query=", timeout=5)
                if all_response.status_code == 200:
                    all_data = all_response.json()
                    print(f"전체 데이터 수: {len(all_data)}개")
                    
                    # 마지막 단계가 있는 항목들 몇 개 확인
                    print("\n📋 마지막 단계가 있는 다른 항목들:")
                    count = 0
                    for item in all_data:
                        if item.get('마지막 단계') and count < 5:
                            print(f"  {item.get('ASSEMBLY')}: {item.get('마지막 단계')} ({item.get('마지막 단계 날짜')})")
                            count += 1
            else:
                print("❌ 검색 결과가 없습니다.")
        else:
            print(f"❌ 검색 실패: {response.status_code}")
            print(f"응답: {response.text}")
            
    except Exception as e:
        print(f"❌ 오류: {e}")

if __name__ == "__main__":
    test_specific_assembly()

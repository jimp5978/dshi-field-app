# -*- coding: utf-8 -*-
import requests
import json

def test_api():
    base_url = "http://localhost:5000"
    
    print("=== DSHI Field Pad API 테스트 ===\n")
    
    # 1. 서버 상태 확인
    try:
        print("1. 서버 상태 확인...")
        response = requests.get(f"{base_url}/")
        if response.status_code == 200:
            print("✅ 서버 정상 작동")
            print(f"   응답: {response.json()}")
        else:
            print(f"❌ 서버 오류 (Status: {response.status_code})")
    except Exception as e:
        print(f"❌ 서버 연결 실패: {e}")
        return
    
    print("\n" + "="*50 + "\n")
    
    # 2. 테스트 API 확인
    try:
        print("2. 테스트 API 확인...")
        response = requests.get(f"{base_url}/api/test")
        if response.status_code == 200:
            print("✅ 테스트 API 정상")
            data = response.json()
            print(f"   서버 시간: {data['server_time']}")
            print(f"   Assembly 수: {data['test_data']['assemblies_count']}")
            print(f"   사용자 수: {data['test_data']['users_count']}")
        else:
            print(f"❌ 테스트 API 오류 (Status: {response.status_code})")
    except Exception as e:
        print(f"❌ 테스트 API 실패: {e}")
    
    print("\n" + "="*50 + "\n")
    
    # 3. 로그인 테스트
    try:
        print("3. 로그인 테스트...")
        login_data = {
            "username": "admin",
            "password_hash": "admin123"
        }
        response = requests.post(f"{base_url}/api/login", json=login_data)
        if response.status_code == 200:
            print("✅ 로그인 성공")
            user_info = response.json()['user']
            print(f"   사용자: {user_info['full_name']} (Level {user_info['permission_level']})")
        else:
            print(f"❌ 로그인 실패 (Status: {response.status_code})")
            print(f"   응답: {response.json()}")
    except Exception as e:
        print(f"❌ 로그인 테스트 실패: {e}")
    
    print("\n" + "="*50 + "\n")
    
    # 4. Assembly 검색 테스트
    try:
        print("4. Assembly 검색 테스트...")
        search_data = {
            "search_query": "RF"
        }
        response = requests.post(f"{base_url}/api/search_assembly", json=search_data)
        if response.status_code == 200:
            print("✅ 검색 성공")
            results = response.json()['results']
            print(f"   검색 결과: {len(results)}개")
            for result in results:
                print(f"   - {result['assembly_code']}: {result['zone']} ({result['next_process']})")
        else:
            print(f"❌ 검색 실패 (Status: {response.status_code})")
    except Exception as e:
        print(f"❌ 검색 테스트 실패: {e}")
    
    print("\n" + "="*50 + "\n")
    
    # 5. 공정 업데이트 테스트
    try:
        print("5. 공정 업데이트 테스트...")
        update_data = {
            "assembly_code": "RF-031-M2-SE-SD589",
            "process_name": "VIDI"
        }
        response = requests.post(f"{base_url}/api/update_process", json=update_data)
        if response.status_code == 200:
            print("✅ 공정 업데이트 성공")
            print(f"   응답: {response.json()['message']}")
        else:
            print(f"❌ 공정 업데이트 실패 (Status: {response.status_code})")
    except Exception as e:
        print(f"❌ 공정 업데이트 테스트 실패: {e}")
    
    print("\n" + "="*50 + "\n")
    
    # 6. 롤백 사유 목록 테스트
    try:
        print("6. 롤백 사유 목록 테스트...")
        response = requests.get(f"{base_url}/api/rollback_reasons")
        if response.status_code == 200:
            print("✅ 롤백 사유 목록 조회 성공")
            reasons = response.json()['reasons']
            print(f"   사유 개수: {len(reasons)}개")
            for reason in reasons:
                print(f"   - {reason['id']}: {reason['reason_text']}")
        else:
            print(f"❌ 롤백 사유 목록 실패 (Status: {response.status_code})")
    except Exception as e:
        print(f"❌ 롤백 사유 테스트 실패: {e}")
    
    print("\n" + "="*50)
    print("API 테스트 완료!")

if __name__ == "__main__":
    test_api()

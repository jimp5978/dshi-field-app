#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
간단한 연결 테스트 도구
Android 에뮬레이터에서 접근할 수 있는지 확인
"""
import requests
import json

def test_connection():
    print("=== DSHI Field Pad 연결 테스트 ===")
    
    # 1. localhost 테스트
    print("\n1. Localhost 테스트...")
    try:
        response = requests.get("http://localhost:5000/api/test", timeout=5)
        print(f"✅ localhost:5000 - 상태: {response.status_code}")
        print(f"   응답: {response.json()}")
    except Exception as e:
        print(f"❌ localhost:5000 - 오류: {e}")
    
    # 2. 127.0.0.1 테스트
    print("\n2. 127.0.0.1 테스트...")
    try:
        response = requests.get("http://127.0.0.1:5000/api/test", timeout=5)
        print(f"✅ 127.0.0.1:5000 - 상태: {response.status_code}")
        print(f"   응답: {response.json()}")
    except Exception as e:
        print(f"❌ 127.0.0.1:5000 - 오류: {e}")
    
    # 3. 로그인 테스트
    print("\n3. 로그인 테스트...")
    try:
        login_data = {
            "username": "admin",
            "password_hash": "admin123"  # 테스트용 평문
        }
        response = requests.post("http://localhost:5000/api/login", 
                               json=login_data, timeout=5)
        print(f"✅ 로그인 테스트 - 상태: {response.status_code}")
        print(f"   응답: {response.json()}")
    except Exception as e:
        print(f"❌ 로그인 테스트 - 오류: {e}")

if __name__ == "__main__":
    test_connection()

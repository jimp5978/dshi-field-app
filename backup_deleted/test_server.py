# -*- coding: utf-8 -*-
from flask import Flask, jsonify, request
import json
from datetime import datetime

app = Flask(__name__)

# 테스트용 더미 데이터
test_assemblies = [
    {
        "assembly_code": "RF-031-M2-SE-SD589",
        "zone": "Secondary_Truss", 
        "item": "RF Beam",
        "fit_up_date": "2024-01-15",
        "nde_date": "2024-01-20",
        "vidi_date": None,
        "galv_date": None,
        "shot_date": None,
        "paint_date": None,
        "packing_date": None
    },
    {
        "assembly_code": "TN1-001-B1-SE-SD123", 
        "zone": "Main_Truss",
        "item": "TN Beam",
        "fit_up_date": "2024-01-10",
        "nde_date": "2024-01-12", 
        "vidi_date": "2024-01-15",
        "galv_date": None,
        "shot_date": None,
        "paint_date": None,
        "packing_date": None
    },
    {
        "assembly_code": "CB-045-C3-SE-SD456",
        "zone": "Cable_Bridge", 
        "item": "CB Support",
        "fit_up_date": "2024-01-05",
        "nde_date": "2024-01-08",
        "vidi_date": "2024-01-12",
        "galv_date": "2024-01-18",
        "shot_date": None,
        "paint_date": None,
        "packing_date": None
    }
]

test_users = [
    {
        "id": 1,
        "username": "admin",
        "password_hash": "admin123",  # 실제로는 해시화해야 함
        "full_name": "관리자",
        "permission_level": 5
    },
    {
        "id": 2,
        "username": "test_level1", 
        "password_hash": "test123",
        "full_name": "외부업체1",
        "permission_level": 1
    },
    {
        "id": 3,
        "username": "test_level3",
        "password_hash": "test123", 
        "full_name": "DSHI 현장직원",
        "permission_level": 3
    }
]

@app.route('/')
def home():
    return jsonify({
        "message": "DSHI Field Pad API 서버가 정상 작동 중입니다!",
        "version": "1.0.0",
        "endpoints": [
            "/api/login",
            "/api/search_assembly", 
            "/api/test"
        ]
    })

@app.route('/api/test')
def test():
    return jsonify({
        "status": "success",
        "message": "API 테스트 성공!",
        "server_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "test_data": {
            "assemblies_count": len(test_assemblies),
            "users_count": len(test_users)
        }
    })

@app.route('/api/login', methods=['POST'])
def login():
    try:
        data = request.get_json()
        username = data.get('username')
        password_hash = data.get('password_hash')
        
        print(f"로그인 시도: {username}")
        
        # 사용자 검증
        user = None
        for u in test_users:
            if u['username'] == username and u['password_hash'] == password_hash:
                user = u
                break
        
        if user:
            return jsonify({
                'success': True,
                'message': '로그인 성공',
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'full_name': user['full_name'],
                    'permission_level': user['permission_level']
                }
            })
        else:
            return jsonify({
                'success': False,
                'message': '아이디 또는 비밀번호가 잘못되었습니다'
            }), 401
            
    except Exception as e:
        print(f"로그인 오류: {e}")
        return jsonify({
            'success': False,
            'message': '서버 오류가 발생했습니다'
        }), 500

@app.route('/api/search_assembly', methods=['POST'])
def search_assembly():
    try:
        data = request.get_json()
        search_query = data.get('search_query', '').upper()
        
        print(f"검색 요청: {search_query}")
        
        # 검색 결과 필터링
        results = []
        for assembly in test_assemblies:
            if search_query in assembly['assembly_code'].upper():
                # 다음 공정 결정
                next_process = get_next_process(assembly)
                
                result = assembly.copy()
                result['next_process'] = next_process
                result['can_proceed'] = next_process is not None
                results.append(result)
        
        return jsonify({
            'success': True,
            'results': results,
            'total_count': len(results)
        })
        
    except Exception as e:
        print(f"검색 오류: {e}")
        return jsonify({
            'success': False,
            'message': '검색 중 오류가 발생했습니다'
        }), 500

@app.route('/api/update_process', methods=['POST'])
def update_process():
    try:
        data = request.get_json()
        assembly_code = data.get('assembly_code')
        process_name = data.get('process_name')
        
        print(f"공정 업데이트: {assembly_code} - {process_name}")
        
        # 해당 assembly 찾기
        assembly = None
        for i, a in enumerate(test_assemblies):
            if a['assembly_code'] == assembly_code:
                assembly = test_assemblies[i]
                break
        
        if not assembly:
            return jsonify({
                'success': False,
                'message': 'ASSEMBLY를 찾을 수 없습니다'
            }), 404
        
        # 공정 업데이트
        today = datetime.now().strftime("%Y-%m-%d")
        process_field_map = {
            'Fit-up': 'fit_up_date',
            'NDE': 'nde_date',
            'VIDI': 'vidi_date',
            'GALV': 'galv_date',
            'SHOT': 'shot_date',
            'PAINT': 'paint_date',
            'PACKING': 'packing_date'
        }
        
        if process_name in process_field_map:
            field_name = process_field_map[process_name]
            assembly[field_name] = today
            
            return jsonify({
                'success': True,
                'message': f'{process_name} 공정이 완료되었습니다',
                'updated_assembly': assembly
            })
        else:
            return jsonify({
                'success': False,
                'message': '잘못된 공정명입니다'
            }), 400
            
    except Exception as e:
        print(f"업데이트 오류: {e}")
        return jsonify({
            'success': False,
            'message': '업데이트 중 오류가 발생했습니다'
        }), 500

@app.route('/api/rollback_reasons', methods=['GET'])
def get_rollback_reasons():
    return jsonify({
        'success': True,
        'reasons': [
            {'id': 1, 'reason_text': '용접 불량'},
            {'id': 2, 'reason_text': '치수 오차'},
            {'id': 3, 'reason_text': '재료 문제'},
            {'id': 4, 'reason_text': '설계 변경'},
            {'id': 5, 'reason_text': '기타'}
        ]
    })

def get_next_process(assembly):
    """다음 진행 가능한 공정 결정"""
    processes = ['fit_up_date', 'nde_date', 'vidi_date', 'galv_date', 'shot_date', 'paint_date', 'packing_date']
    process_names = ['Fit-up', 'NDE', 'VIDI', 'GALV', 'SHOT', 'PAINT', 'PACKING']
    
    for i, process_field in enumerate(processes):
        if assembly[process_field] is None:
            return process_names[i]
    
    return None  # 모든 공정 완료

if __name__ == '__main__':
    print("DSHI Field Pad 테스트 서버 시작...")
    print("사용 가능한 엔드포인트:")
    print("  GET  /")
    print("  GET  /api/test")
    print("  POST /api/login")
    print("  POST /api/search_assembly")
    print("  POST /api/update_process")
    print("  GET  /api/rollback_reasons")
    print("\n테스트 계정:")
    for user in test_users:
        print(f"  {user['username']} / {user['password_hash']} (Level {user['permission_level']})")
    print("\n서버 시작 중...")
    
    app.run(host='0.0.0.0', port=5000, debug=True)

# -*- coding: utf-8 -*-
"""
DSHI Field Pad MySQL 기반 Flask 서버
실제 MySQL 데이터베이스 연동 버전
"""
from flask import Flask, request, jsonify
import pymysql.cursors
from datetime import datetime, date
import json

app = Flask(__name__)

# MySQL 접속 설정 (import_data.py와 동일)
MYSQL_HOST = 'localhost'
MYSQL_USER = 'field_app_user'
MYSQL_PASSWORD = 'F!eldApp_Pa$$w0rd_2025#'
MYSQL_DB = 'field_app_db'

def get_db():
    return pymysql.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DB,
        cursorclass=pymysql.cursors.DictCursor
    )

@app.route('/')
def home():
    return jsonify({
        "message": "DSHI Field Pad API 서버 (MySQL 연동 버전)",
        "version": "1.0.0-mysql",
        "database": "MySQL field_app_db",
        "status": "running"
    })

@app.route('/api/test')
def test():
    try:
        conn = get_db()
        cursor = conn.cursor()
        
        # assembly_items 수 확인
        cursor.execute("SELECT COUNT(*) as total FROM assembly_items")
        assembly_count = cursor.fetchone()['total']
        
        # users 수 확인
        cursor.execute("SELECT COUNT(*) as total FROM users")
        user_count = cursor.fetchone()['total']
        
        conn.close()
        
        return jsonify({
            "status": "success",
            "message": "MySQL 연결 및 API 테스트 성공!",
            "server_time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "database_info": {
                "assemblies_count": assembly_count,
                "users_count": user_count,
                "database": "MySQL field_app_db"
            }
        })
    except Exception as e:
        return jsonify({
            "status": "error",
            "message": f"데이터베이스 연결 오류: {str(e)}"
        }), 500

@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password_hash = data.get('password_hash')
    
    if not username or not password_hash:
        return jsonify({
            'success': False,
            'message': '아이디와 비밀번호를 입력해주세요'
        })
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # 사용자 정보 조회
        cursor.execute("""
            SELECT id, username, full_name, permission_level
            FROM users 
            WHERE username = %s AND password_hash = %s
        """, (username, password_hash))
        
        user = cursor.fetchone()
        
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
    finally:
        conn.close()

@app.route('/api/search_assembly', methods=['POST'])
def search_assembly():
    data = request.get_json()
    search_query = data.get('search_query', '').upper()
    
    if not search_query:
        return jsonify({
            'success': False,
            'message': '검색어를 입력해주세요'
        })
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # ASSEMBLY 검색 (부분 일치)
        cursor.execute("""
            SELECT assembly_code, zone, item,
                   fit_up_date, nde_date, vidi_date, galv_date,
                   shot_date, paint_date, packing_date
            FROM assembly_items 
            WHERE UPPER(assembly_code) LIKE %s
            ORDER BY assembly_code
            LIMIT 50
        """, (f'%{search_query}%',))
        
        results = cursor.fetchall()
        
        # 결과 처리 및 다음 공정 계산
        processed_results = []
        for row in results:
            # 다음 공정 결정
            next_process = get_next_process(row)
            
            # 날짜를 문자열로 변환
            result = {}
            for key, value in row.items():
                if isinstance(value, date):
                    result[key] = value.strftime('%Y-%m-%d')
                else:
                    result[key] = value
            
            result['next_process'] = next_process
            result['can_proceed'] = next_process is not None
            processed_results.append(result)
        
        return jsonify({
            'success': True,
            'results': processed_results,
            'total_count': len(processed_results),
            'search_query': search_query
        })
        
    except Exception as e:
        print(f"검색 오류: {e}")
        return jsonify({
            'success': False,
            'message': '검색 중 오류가 발생했습니다'
        }), 500
    finally:
        conn.close()

def get_next_process(assembly_row):
    """다음 진행 가능한 공정 결정"""
    processes = ['fit_up_date', 'nde_date', 'vidi_date', 'galv_date', 'shot_date', 'paint_date', 'packing_date']
    process_names = ['Fit-up', 'NDE', 'VIDI', 'GALV', 'SHOT', 'PAINT', 'PACKING']
    
    for i, process_field in enumerate(processes):
        if assembly_row[process_field] is None:
            return process_names[i]
    
    return None  # 모든 공정 완료

@app.route('/api/update_process', methods=['POST'])
def update_process():
    data = request.get_json()
    assembly_code = data.get('assembly_code')
    process_name = data.get('process_name')
    
    if not assembly_code or not process_name:
        return jsonify({
            'success': False,
            'message': 'ASSEMBLY 코드와 공정명이 필요합니다'
        })
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # 공정명을 데이터베이스 컬럼명으로 변환
        process_field_map = {
            'Fit-up': 'fit_up_date',
            'NDE': 'nde_date',
            'VIDI': 'vidi_date',
            'GALV': 'galv_date',
            'SHOT': 'shot_date',
            'PAINT': 'paint_date',
            'PACKING': 'packing_date'
        }
        
        if process_name not in process_field_map:
            return jsonify({
                'success': False,
                'message': '잘못된 공정명입니다'
            }), 400
        
        field_name = process_field_map[process_name]
        today = datetime.now().strftime("%Y-%m-%d")
        
        # 해당 ASSEMBLY가 존재하는지 확인
        cursor.execute("SELECT assembly_code FROM assembly_items WHERE assembly_code = %s", (assembly_code,))
        if not cursor.fetchone():
            return jsonify({
                'success': False,
                'message': 'ASSEMBLY를 찾을 수 없습니다'
            }), 404
        
        # 공정 업데이트
        update_sql = f"UPDATE assembly_items SET {field_name} = %s WHERE assembly_code = %s"
        cursor.execute(update_sql, (today, assembly_code))
        
        if cursor.rowcount > 0:
            conn.commit()
            return jsonify({
                'success': True,
                'message': f'{assembly_code}의 {process_name} 공정이 완료되었습니다',
                'updated_date': today
            })
        else:
            return jsonify({
                'success': False,
                'message': '업데이트에 실패했습니다'
            }), 500
            
    except Exception as e:
        print(f"업데이트 오류: {e}")
        conn.rollback()
        return jsonify({
            'success': False,
            'message': '업데이트 중 오류가 발생했습니다'
        }), 500
    finally:
        conn.close()

@app.route('/api/rollback_reasons', methods=['GET'])
def get_rollback_reasons():
    """롤백 사유 목록 반환"""
    return jsonify({
        'success': True,
        'reasons': [
            {'id': 1, 'reason_text': '용접 불량'},
            {'id': 2, 'reason_text': '치수 오차'},
            {'id': 3, 'reason_text': '재료 문제'},
            {'id': 4, 'reason_text': '설계 변경'},
            {'id': 5, 'reason_text': '검사 불합격'},
            {'id': 6, 'reason_text': '기타'}
        ]
    })

if __name__ == '__main__':
    print("=" * 60)
    print("DSHI Field Pad MySQL 서버 시작...")
    print("=" * 60)
    print("데이터베이스: MySQL field_app_db")
    print("포트: 5001")
    print("API 엔드포인트:")
    print("  GET  /")
    print("  GET  /api/test")
    print("  POST /api/login")
    print("  POST /api/search_assembly")
    print("  POST /api/update_process")
    print("  GET  /api/rollback_reasons")
    print()
    print("테스트 계정:")
    print("  admin / admin123 (Level 5)")
    print("  test_level1 / test123 (Level 1)")
    print("  test_level3 / test123 (Level 3)")
    print()
    print("서버 시작 중...")
    print("=" * 60)
    
    app.run(host='0.0.0.0', port=5001, debug=True)

from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import hashlib
import jwt
import datetime
from functools import wraps
import os

app = Flask(__name__)
CORS(app)

# JWT 설정
app.config['SECRET_KEY'] = 'dshi-field-pad-secret-key-2025'

# MySQL 연결 설정
from config_env import get_db_config, get_server_config
DB_CONFIG = get_db_config()
SERVER_CONFIG = get_server_config()

def get_db_connection():
    """데이터베이스 연결 함수"""
    try:
        connection = mysql.connector.connect(**DB_CONFIG)
        return connection
    except Error as e:
        print(f"데이터베이스 연결 오류: {e}")
        return None

def token_required(f):
    """JWT 토큰 검증 데코레이터"""
    @wraps(f)
    def decorated(*args, **kwargs):
        token = request.headers.get('Authorization')
        
        if not token:
            return jsonify({'message': '토큰이 없습니다'}), 401
        
        try:
            if token.startswith('Bearer '):
                token = token[7:]
            
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=['HS256'])
            current_user = data['user_id']
        except:
            return jsonify({'message': '토큰이 유효하지 않습니다'}), 401
        
        return f(current_user, *args, **kwargs)
    return decorated

@app.route('/api/login', methods=['POST'])
def login():
    """사용자 로그인"""
    try:
        data = request.get_json()
        username = data.get('username')
        password_hash = data.get('password_hash')
        
        if not username or not password_hash:
            return jsonify({'success': False, 'message': '아이디와 비밀번호를 입력하세요'}), 400
        
        # 테스트용 하드코딩된 사용자 계정 (SHA256 해시값)
        test_users = {
            'a': {
                'password_hash': 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',  # SHA256('a')
                'full_name': 'Admin',
                'permission_level': 1,
                'id': 1
            },
            'l1': {
                'password_hash': '2804bad6fe94a55f18b2b37e300919a5fd517b95aa81e95db574c0ba069a3740',  # SHA256('l1')
                'full_name': 'Level 1 User',
                'permission_level': 1,
                'id': 2
            },
            'l3': {
                'password_hash': '10dacdccfe877dc064d57442e6fa7a4e3085dc94e11a29819c2290fc3d788724',  # SHA256('l3')
                'full_name': 'Level 3 User', 
                'permission_level': 3,
                'id': 3
            },
            'l5': {
                'password_hash': 'a99e27f8d40e114ff48dc9c44b04cd7418328c15b7a5ed0ceeaa180783c45fa0',  # SHA256('l5')
                'full_name': 'Level 5 User',
                'permission_level': 5,
                'id': 4
            }
        }
        
        if username in test_users and test_users[username]['password_hash'] == password_hash:
            user = test_users[username]
            
            # JWT 토큰 생성
            token = jwt.encode({
                'user_id': user['id'],
                'username': username,
                'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
            }, app.config['SECRET_KEY'])
            
            return jsonify({
                'success': True,
                'token': token,
                'user': {
                    'id': user['id'],
                    'username': username,
                    'full_name': user['full_name'],
                    'permission_level': user['permission_level']
                }
            })
        else:
            return jsonify({'success': False, 'message': '아이디 또는 비밀번호가 틀렸습니다'}), 401
            
    except Exception as e:
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/assemblies', methods=['GET'])
def get_assemblies():
    """조립품 목록 조회"""
    try:
        search = request.args.get('search', '')
        
        if not search:
            return jsonify({'success': False, 'message': '검색어를 입력하세요'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # assembly_code 끝 3자리 숫자로 검색
        cursor.execute("""
            SELECT 
                id,
                assembly_code,
                zone,
                item,
                fit_up_date,
                nde_date,
                vidi_date,
                galv_date,
                shot_date,
                paint_date,
                packing_date
            FROM assembly_items 
            WHERE RIGHT(assembly_code, 3) = %s
            ORDER BY assembly_code
            LIMIT 50
        """, (search,))
        
        rows = cursor.fetchall()
        cursor.close()
        connection.close()
        
        # 데이터 변환 (앱 형식에 맞게)
        assemblies = []
        for row in rows:
            # 최종 완료된 공정 찾기
            processes = [
                ('Fit-up', row['fit_up_date']),
                ('NDE', row['nde_date']),
                ('VIDI', row['vidi_date']),
                ('GALV', row['galv_date']),
                ('SHOT', row['shot_date']),
                ('PAINT', row['paint_date']),
                ('PACKING', row['packing_date'])
            ]
            
            # 완료된 공정들만 필터링 (None과 1900-01-01 제외)
            completed_processes = []
            for name, date in processes:
                if date is not None and date != datetime.date(1900, 1, 1):
                    completed_processes.append((name, date))
            
            if completed_processes:
                # 가장 마지막 완료된 공정
                last_process_name, last_date = completed_processes[-1]
                status = '완료' if len(completed_processes) == 7 else '진행중'
                completed_date = last_date.strftime('%Y-%m-%d') if last_date else ''
            else:
                last_process_name = '시작전'
                status = '대기'
                completed_date = ''
            
            assemblies.append({
                'id': str(row['id']),
                'name': row['assembly_code'],
                'location': row['zone'] or '',
                'status': status,
                'drawing_number': row['item'] or '',
                'lastProcess': last_process_name,
                'completedDate': completed_date
            })
        
        return jsonify({
            'success': True,
            'assemblies': assemblies
        })
        
    except Exception as e:
        print(f"검색 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/assemblies/search', methods=['GET'])
@token_required
def search_assemblies(current_user):
    """조립품 검색"""
    try:
        query = request.args.get('q', '')
        
        if not query:
            return jsonify({'success': False, 'message': '검색어를 입력하세요'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        search_pattern = f"%{query}%"
        
        cursor.execute("""
            SELECT id, assembly_name, drawing_number, revision, 
                   created_date, status
            FROM assemblies 
            WHERE assembly_name LIKE %s OR drawing_number LIKE %s
            ORDER BY created_date DESC
        """, (search_pattern, search_pattern))
        
        assemblies = cursor.fetchall()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': assemblies
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-requests', methods=['POST'])
@token_required
def create_inspection_request(current_user):
    """검사신청 생성"""
    try:
        data = request.get_json()
        assembly_codes = data.get('assembly_codes', [])
        inspection_type = data.get('inspection_type')
        request_date = data.get('request_date')
        
        if not assembly_codes or not inspection_type or not request_date:
            return jsonify({'success': False, 'message': '필수 데이터가 누락되었습니다'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor()
        
        # 테스트용 하드코딩된 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 1},
            2: {'username': 'l1', 'full_name': 'Level 1 User', 'permission_level': 1},
            3: {'username': 'l3', 'full_name': 'Level 3 User', 'permission_level': 3},
            4: {'username': 'l5', 'full_name': 'Level 5 User', 'permission_level': 5}
        }
        
        if current_user not in test_users:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        user_info = test_users[current_user]
        username = user_info['username']
        full_name = user_info['full_name']
        
        # 여러 ASSEMBLY에 대해 검사신청 저장
        inserted_count = 0
        for assembly_code in assembly_codes:
            cursor.execute("""
                INSERT INTO inspection_requests (
                    assembly_code, 
                    inspection_type, 
                    requested_by_user_id, 
                    requested_by_name, 
                    request_date
                ) VALUES (%s, %s, %s, %s, %s)
            """, (assembly_code, inspection_type, current_user, full_name, request_date))
            inserted_count += 1
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'{inserted_count}개 항목의 {inspection_type} 검사가 신청되었습니다',
            'inserted_count': inserted_count
        })
        
    except Exception as e:
        print(f"검사신청 생성 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-requests', methods=['GET'])
@token_required  
def get_inspection_requests(current_user):
    """검사신청 목록 조회 (Level별 필터링)"""
    try:
        request_date = request.args.get('date')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 테스트용 하드코딩된 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 1},
            2: {'username': 'l1', 'full_name': 'Level 1 User', 'permission_level': 1},
            3: {'username': 'l3', 'full_name': 'Level 3 User', 'permission_level': 3},
            4: {'username': 'l5', 'full_name': 'Level 5 User', 'permission_level': 5}
        }
        
        if current_user not in test_users:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        permission_level = test_users[current_user]['permission_level']
        
        # Level별 쿼리 분기
        if permission_level == 1:
            # Level 1: 본인이 신청한 것만
            if request_date:
                cursor.execute("""
                    SELECT * FROM inspection_requests 
                    WHERE requested_by_user_id = %s AND request_date = %s
                    ORDER BY created_at DESC
                """, (current_user, request_date))
            else:
                cursor.execute("""
                    SELECT * FROM inspection_requests 
                    WHERE requested_by_user_id = %s
                    ORDER BY created_at DESC
                """, (current_user,))
        else:
            # Level 3+: 전체 검사신청
            if request_date:
                cursor.execute("""
                    SELECT * FROM inspection_requests 
                    WHERE request_date = %s
                    ORDER BY created_at DESC
                """, (request_date,))
            else:
                cursor.execute("""
                    SELECT * FROM inspection_requests 
                    ORDER BY created_at DESC
                """)
        
        requests = cursor.fetchall()
        
        # 날짜 형식을 문자열로 변환 (JSON 직렬화 문제 해결)
        for req_item in requests:
            try:
                if 'request_date' in req_item and req_item['request_date'] is not None:
                    if hasattr(req_item['request_date'], 'strftime'):
                        req_item['request_date'] = req_item['request_date'].strftime('%Y-%m-%d')
                    else:
                        req_item['request_date'] = str(req_item['request_date'])
                        
                if 'created_at' in req_item and req_item['created_at'] is not None:
                    if hasattr(req_item['created_at'], 'strftime'):
                        req_item['created_at'] = req_item['created_at'].strftime('%Y-%m-%d %H:%M:%S')
                    else:
                        req_item['created_at'] = str(req_item['created_at'])
            except Exception as e:
                print(f"날짜 변환 오류: {e}")
                # 오류 시 기본값 설정
                req_item['request_date'] = '2025-07-16'
                req_item['created_at'] = '2025-07-16 00:00:00'
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'requests': requests,
            'user_level': permission_level
        })
        
    except Exception as e:
        print(f"검사신청 조회 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/health', methods=['GET'])
def health_check():
    """서버 상태 확인"""
    return jsonify({
        'status': 'ok',
        'message': 'DSHI Field Pad Server is running',
        'timestamp': datetime.datetime.now().isoformat()
    })

if __name__ == '__main__':
    print("DSHI Field Pad Server starting...")
    print(f"Server URL: http://{SERVER_CONFIG['host']}:{SERVER_CONFIG['port']}")
    app.run(**SERVER_CONFIG)
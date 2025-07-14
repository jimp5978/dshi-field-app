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
DB_CONFIG = {
    'host': 'localhost',
    'database': 'field_app_db',
    'user': 'field_app_user',
    'password': 'dshi2025#',
    'charset': 'utf8mb4'
}

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
            
            # 완료된 공정들만 필터링
            completed_processes = [(name, date) for name, date in processes if date is not None]
            
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
    print("Server URL: http://localhost:5001")
    app.run(host='0.0.0.0', port=5001, debug=True)
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
        
        # 실제 사용자 계정 (SHA256 해시값)
        test_users = {
            'a': {
                'password_hash': 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb',  # SHA256('a')
                'full_name': 'Admin',
                'permission_level': 5,
                'id': 1
            },
            'seojin': {
                'password_hash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',  # SHA256('1234')
                'full_name': '서진',
                'permission_level': 1,
                'id': 2
            },
            'sookang': {
                'password_hash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',  # SHA256('1234')
                'full_name': '수강',
                'permission_level': 1,
                'id': 3
            },
            'gyeongin': {
                'password_hash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',  # SHA256('1234')
                'full_name': '경인',
                'permission_level': 1,
                'id': 4
            },
            'dshi_hy': {
                'password_hash': '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4',  # SHA256('1234')
                'full_name': 'DSHI 현영',
                'permission_level': 3,
                'id': 5
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
        
        cursor = connection.cursor(dictionary=True)
        
        # 실제 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 5},
            2: {'username': 'seojin', 'full_name': '서진', 'permission_level': 1},
            3: {'username': 'sookang', 'full_name': '수강', 'permission_level': 1},
            4: {'username': 'gyeongin', 'full_name': '경인', 'permission_level': 1},
            5: {'username': 'dshi_hy', 'full_name': 'DSHI 현영', 'permission_level': 3}
        }
        
        if current_user not in test_users:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        user_info = test_users[current_user]
        username = user_info['username']
        full_name = user_info['full_name']
        
        # 중복 체크 및 검사신청 저장
        inserted_count = 0
        duplicate_items = []
        
        for assembly_code in assembly_codes:
            # 선착순 체크: 같은 ASSEMBLY + 같은 검사타입이 이미 있는지 확인 (취소된 항목 제외)
            cursor.execute("""
                SELECT id, requested_by_name, request_date 
                FROM inspection_requests 
                WHERE assembly_code = %s AND inspection_type = %s AND status != '취소됨'
                LIMIT 1
            """, (assembly_code, inspection_type))
            
            existing_request = cursor.fetchone()
            
            if existing_request:
                # 이미 신청된 항목
                duplicate_items.append({
                    'assembly_code': assembly_code,
                    'existing_requester': existing_request['requested_by_name'],
                    'existing_date': existing_request['request_date'].strftime('%Y-%m-%d')
                })
            else:
                # 새로 신청 가능한 항목
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
        
        # 결과 메시지 생성
        if inserted_count > 0 and len(duplicate_items) == 0:
            # 모두 성공
            return jsonify({
                'success': True,
                'message': f'{inserted_count}개 항목의 {inspection_type} 검사가 신청되었습니다',
                'inserted_count': inserted_count,
                'duplicate_items': []
            })
        elif inserted_count > 0 and len(duplicate_items) > 0:
            # 일부 성공, 일부 중복
            return jsonify({
                'success': True,
                'message': f'{inserted_count}개 항목 신청 완료, {len(duplicate_items)}개 항목 중복',
                'inserted_count': inserted_count,
                'duplicate_items': duplicate_items
            })
        else:
            # 모두 중복
            return jsonify({
                'success': False,
                'message': '선택한 모든 항목이 이미 신청되어 있습니다',
                'inserted_count': 0,
                'duplicate_items': duplicate_items
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
        
        # 실제 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 5},
            2: {'username': 'seojin', 'full_name': '서진', 'permission_level': 1},
            3: {'username': 'sookang', 'full_name': '수강', 'permission_level': 1},
            4: {'username': 'gyeongin', 'full_name': '경인', 'permission_level': 1},
            5: {'username': 'dshi_hy', 'full_name': 'DSHI 현영', 'permission_level': 3}
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

@app.route('/api/inspection-requests/<int:request_id>/approve', methods=['PUT'])
@token_required
def approve_inspection_request(current_user, request_id):
    """검사신청 승인 (Level 3+ 전용)"""
    try:
        # 실제 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 5},
            2: {'username': 'seojin', 'full_name': '서진', 'permission_level': 1},
            3: {'username': 'sookang', 'full_name': '수강', 'permission_level': 1},
            4: {'username': 'gyeongin', 'full_name': '경인', 'permission_level': 1},
            5: {'username': 'dshi_hy', 'full_name': 'DSHI 현영', 'permission_level': 3}
        }
        
        if current_user not in test_users:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        user_info = test_users[current_user]
        permission_level = user_info['permission_level']
        
        # Level 3+ 권한 확인
        if permission_level < 3:
            return jsonify({'success': False, 'message': '승인 권한이 없습니다'}), 403
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 해당 검사신청이 존재하고 대기중인지 확인
        cursor.execute("""
            SELECT * FROM inspection_requests 
            WHERE id = %s AND status = '대기중'
        """, (request_id,))
        
        inspection_request = cursor.fetchone()
        
        if not inspection_request:
            return jsonify({'success': False, 'message': '승인할 수 있는 검사신청이 없습니다'}), 404
        
        # 승인 처리
        today = datetime.datetime.now().date()
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = '승인됨',
                approved_by_user_id = %s,
                approved_by_name = %s,
                approved_date = %s
            WHERE id = %s
        """, (current_user, user_info['full_name'], today, request_id))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'{inspection_request["assembly_code"]} {inspection_request["inspection_type"]} 검사신청이 승인되었습니다'
        })
        
    except Exception as e:
        print(f"검사신청 승인 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-requests/<int:request_id>/confirm', methods=['PUT'])
@token_required
def confirm_inspection_request(current_user, request_id):
    """검사신청 확정 (Level 3+ 전용) - assembly_items 테이블도 업데이트"""
    try:
        # 실제 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 5},
            2: {'username': 'seojin', 'full_name': '서진', 'permission_level': 1},
            3: {'username': 'sookang', 'full_name': '수강', 'permission_level': 1},
            4: {'username': 'gyeongin', 'full_name': '경인', 'permission_level': 1},
            5: {'username': 'dshi_hy', 'full_name': 'DSHI 현영', 'permission_level': 3}
        }
        
        if current_user not in test_users:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        user_info = test_users[current_user]
        permission_level = user_info['permission_level']
        
        # Level 3+ 권한 확인
        if permission_level < 3:
            return jsonify({'success': False, 'message': '확정 권한이 없습니다'}), 403
        
        data = request.get_json()
        confirmed_date = data.get('confirmed_date')  # 실제 검사 완료 날짜
        
        if not confirmed_date:
            return jsonify({'success': False, 'message': '확정 날짜를 입력하세요'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 해당 검사신청이 존재하고 승인됨 상태인지 확인
        cursor.execute("""
            SELECT * FROM inspection_requests 
            WHERE id = %s AND status = '승인됨'
        """, (request_id,))
        
        inspection_request = cursor.fetchone()
        
        if not inspection_request:
            return jsonify({'success': False, 'message': '확정할 수 있는 검사신청이 없습니다'}), 404
        
        # 검사타입별 assembly_items 컬럼 매핑
        inspection_type_mapping = {
            'NDE': 'nde_date',
            'VIDI': 'vidi_date',
            'GALV': 'galv_date',
            'SHOT': 'shot_date',
            'PAINT': 'paint_date',
            'PACKING': 'packing_date'
        }
        
        inspection_type = inspection_request['inspection_type']
        if inspection_type not in inspection_type_mapping:
            return jsonify({'success': False, 'message': f'알 수 없는 검사타입: {inspection_type}'}), 400
        
        assembly_column = inspection_type_mapping[inspection_type]
        assembly_code = inspection_request['assembly_code']
        
        # 트랜잭션 시작
        try:
            # 1. inspection_requests 상태를 확정됨으로 업데이트
            cursor.execute("""
                UPDATE inspection_requests 
                SET status = '확정됨',
                    confirmed_date = %s
                WHERE id = %s
            """, (confirmed_date, request_id))
            
            # 2. assembly_items 테이블의 해당 공정 날짜 업데이트
            update_query = f"""
                UPDATE assembly_items 
                SET {assembly_column} = %s
                WHERE assembly_code = %s
            """
            cursor.execute(update_query, (confirmed_date, assembly_code))
            
            # 업데이트된 행이 있는지 확인
            if cursor.rowcount == 0:
                raise Exception(f'Assembly {assembly_code}를 찾을 수 없습니다')
            
            connection.commit()
            cursor.close()
            connection.close()
            
            return jsonify({
                'success': True,
                'message': f'{assembly_code} {inspection_type} 검사가 확정되었습니다 ({confirmed_date})'
            })
            
        except Exception as e:
            connection.rollback()
            raise e
        
    except Exception as e:
        print(f"검사신청 확정 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-requests/<int:request_id>', methods=['DELETE'])
@token_required
def cancel_inspection_request(current_user, request_id):
    """검사신청 취소 (권한별 제한)"""
    try:
        # 실제 사용자 정보
        test_users = {
            1: {'username': 'a', 'full_name': 'Admin', 'permission_level': 5},
            2: {'username': 'seojin', 'full_name': '서진', 'permission_level': 1},
            3: {'username': 'sookang', 'full_name': '수강', 'permission_level': 1},
            4: {'username': 'gyeongin', 'full_name': '경인', 'permission_level': 1},
            5: {'username': 'dshi_hy', 'full_name': 'DSHI 현영', 'permission_level': 3}
        }
        
        if current_user not in test_users:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        user_info = test_users[current_user]
        permission_level = user_info['permission_level']
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 해당 검사신청 조회
        cursor.execute("""
            SELECT * FROM inspection_requests WHERE id = %s
        """, (request_id,))
        
        inspection_request = cursor.fetchone()
        
        if not inspection_request:
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        # 권한별 취소 제한 확인
        if permission_level == 1:
            # Level 1: 본인이 신청한 대기중 상태만 취소 가능
            if (inspection_request['requested_by_user_id'] != current_user or 
                inspection_request['status'] != '대기중'):
                return jsonify({'success': False, 'message': '취소 권한이 없습니다'}), 403
        
        # Level 3+는 모든 상태 취소 가능
        
        # 트랜잭션 시작
        try:
            # 확정됨 상태에서 취소하는 경우 assembly_items 테이블 롤백 필요
            if inspection_request['status'] == '확정됨':
                # 검사타입별 assembly_items 컬럼 매핑
                inspection_type_mapping = {
                    'NDE': 'nde_date',
                    'VIDI': 'vidi_date',
                    'GALV': 'galv_date',
                    'SHOT': 'shot_date',
                    'PAINT': 'paint_date',
                    'PACKING': 'packing_date'
                }
                
                inspection_type = inspection_request['inspection_type']
                if inspection_type in inspection_type_mapping:
                    assembly_column = inspection_type_mapping[inspection_type]
                    assembly_code = inspection_request['assembly_code']
                    
                    # assembly_items 테이블의 해당 공정 날짜를 NULL로 되돌리기
                    update_query = f"""
                        UPDATE assembly_items 
                        SET {assembly_column} = NULL
                        WHERE assembly_code = %s
                    """
                    cursor.execute(update_query, (assembly_code,))
                    
                    # 업데이트된 행이 있는지 확인
                    if cursor.rowcount == 0:
                        raise Exception(f'Assembly {assembly_code}를 찾을 수 없습니다')
            
            # 취소 처리 (실제로는 상태만 변경)
            cursor.execute("""
                UPDATE inspection_requests 
                SET status = '취소됨'
                WHERE id = %s
            """, (request_id,))
            
            connection.commit()
            
        except Exception as e:
            connection.rollback()
            raise e
        cursor.close()
        connection.close()
        
        # 성공 메시지 생성
        message = f'{inspection_request["assembly_code"]} {inspection_request["inspection_type"]} 검사신청이 취소되었습니다'
        
        # 확정된 항목이 취소된 경우 추가 정보 제공
        if inspection_request['status'] == '확정됨':
            message += ' (조립품 공정 날짜가 되돌려졌습니다)'
        
        return jsonify({
            'success': True,
            'message': message
        })
        
    except Exception as e:
        print(f"검사신청 취소 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/')
def home():
    """루트 경로 - 서버 상태 확인"""
    return jsonify({
        'status': 'ok',
        'message': 'DSHI Field Pad Server is running',
        'timestamp': datetime.datetime.now().isoformat()
    })

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
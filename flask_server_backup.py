from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import hashlib
import jwt
import datetime
from functools import wraps
import os
import json
import logging
from datetime import datetime as dt

app = Flask(__name__)
CORS(app)

# JWT 설정
app.config['SECRET_KEY'] = 'dshi-field-pad-secret-key-2025'

# 디버그 로깅 설정
logging.basicConfig(
    level=logging.DEBUG,
    format='🐛 DEBUG [%(asctime)s]: %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S',
    handlers=[
        logging.FileHandler('flask_debug.log', encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

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

def calculate_assembly_status(assembly_data):
    """조립품 상태 계산 (Ruby ProcessManager 로직과 동일)"""
    try:
        # 8단계 공정 순서
        processes = [
            ('FIT_UP', assembly_data.get('fit_up_date')),
            ('FINAL', assembly_data.get('final_date')),
            ('ARUP_FINAL', assembly_data.get('arup_final_date')),
            ('GALV', assembly_data.get('galv_date')),
            ('ARUP_GALV', assembly_data.get('arup_galv_date')),
            ('SHOT', assembly_data.get('shot_date')),
            ('PAINT', assembly_data.get('paint_date')),
            ('ARUP_PAINT', assembly_data.get('arup_paint_date'))
        ]
        
        # 완료된 공정들과 불필요한 공정들 구분
        completed_processes = []
        skipped_processes = []
        
        for name, date in processes:
            if date and str(date).strip():
                date_str = str(date)
                if '1900' in date_str:
                    # 1900-01-01은 불필요한 공정 (건너뛰기)
                    skipped_processes.append(name)
                else:
                    # 실제 완료된 공정
                    completed_processes.append((name, date))
        
        # 전체 공정 수 (8개) - 건너뛴 공정 수 = 필요한 공정 수
        total_required_processes = 8 - len(skipped_processes)
        
        # 상태 및 마지막 공정 계산
        if completed_processes:
            # 가장 마지막 완료된 공정
            last_process_name, last_date = completed_processes[-1]
            
            # 실제 완료된 공정 수가 필요한 공정 수와 같으면 완료
            status = '완료' if len(completed_processes) >= total_required_processes else '진행중'
            last_process = last_process_name
        else:
            last_process = '시작전'
            status = '대기'
        
        # 다음 공정 계산
        next_process = None
        for name, date in processes:
            if date and str(date).strip():
                date_str = str(date)
                if '1900' in date_str:
                    # 불필요한 공정은 건너뛰기
                    continue
            else:
                # 날짜가 없거나 비어있는 경우 미완료 공정
                next_process = name
                break
        
        # 다음 공정 한국어 변환
        next_process_korean = {
            'FIT_UP': 'FIT-UP',
            'FINAL': 'FINAL',
            'ARUP_FINAL': 'ARUP FINAL',
            'GALV': 'GALV',
            'ARUP_GALV': 'ARUP GALV',
            'SHOT': 'SHOT',
            'PAINT': 'PAINT',
            'ARUP_PAINT': 'ARUP PAINT'
        }.get(next_process, '완료')
        
        # 계산된 상태 정보를 assembly_data에 추가
        assembly_data['status'] = status
        assembly_data['lastProcess'] = last_process
        assembly_data['nextProcess'] = next_process_korean
        
        return assembly_data
        
    except Exception as e:
        print(f"상태 계산 오류: {e}")
        # 오류 시 기본값 설정
        assembly_data['status'] = '오류'
        assembly_data['lastProcess'] = '알 수 없음'
        assembly_data['nextProcess'] = '알 수 없음'
        return assembly_data

def get_user_info(user_id):
    """사용자 정보 조회 헬퍼 함수"""
    try:
        connection = get_db_connection()
        if not connection:
            return None
        
        cursor = connection.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT id, username, full_name, permission_level, company
                FROM users 
                WHERE id = %s AND is_active = TRUE
            """, (user_id,))
        except:
            # company 컬럼이 없는 경우
            cursor.execute("""
                SELECT id, username, full_name, permission_level
                FROM users 
                WHERE id = %s AND is_active = TRUE
            """, (user_id,))
        
        user = cursor.fetchone()
        if user and 'company' not in user:
            user['company'] = ''
        cursor.close()
        connection.close()
        return user
    except Exception as e:
        print(f"사용자 정보 조회 오류: {e}")
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
    """사용자 로그인 - 데이터베이스 기반 (하드코딩 백업)"""
    try:
        data = request.get_json()
        username = data.get('username')
        password_hash = data.get('password_hash')
        
        if not username or not password_hash:
            return jsonify({'success': False, 'message': '아이디와 비밀번호를 입력하세요'}), 400
        
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        try:
            cursor = connection.cursor(dictionary=True)
            
            # 데이터베이스에서 사용자 조회
            try:
                cursor.execute("""
                    SELECT id, username, password_hash, full_name, permission_level, company, is_active
                    FROM users 
                    WHERE username = %s AND is_active = TRUE
                """, (username,))
            except:
                # company 컬럼이 없는 경우
                cursor.execute("""
                    SELECT id, username, password_hash, full_name, permission_level, is_active
                    FROM users 
                    WHERE username = %s AND is_active = TRUE
                """, (username,))
            
            user = cursor.fetchone()
            # company 컬럼이 없는 경우 기본값 설정
            if user and 'company' not in user:
                user['company'] = ''
            cursor.close()
            connection.close()
            
        except Exception as e:
            print(f"데이터베이스 조회 오류: {e}")
            connection.close()
            return jsonify({'success': False, 'message': '데이터베이스 오류'}), 500
        
        # 사용자 인증
        if user and user['password_hash'] == password_hash:
            # JWT 토큰 생성
            token = jwt.encode({
                'user_id': user['id'],
                'username': user['username'],
                'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
            }, app.config['SECRET_KEY'], algorithm='HS256')
            
            return jsonify({
                'success': True,
                'message': '로그인 성공',
                'token': token,
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'full_name': user['full_name'],
                    'permission_level': user['permission_level'],
                    'company': user.get('company', '')
                }
            })
        else:
            return jsonify({'success': False, 'message': '아이디 또는 비밀번호가 틀렸습니다'}), 401
            
    except Exception as e:
        print(f"로그인 오류: {e}")
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
def search_assemblies():
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
        
        # 숫자인지 확인하여 끝 3자리 검색 또는 일반 검색 적용
        if query.isdigit() and len(query) <= 3:
            # 끝 3자리 숫자 검색
            cursor.execute("""
                SELECT assembly_code, company, zone, item, weight_net,
                       fit_up_date, final_date, arup_final_date, galv_date, 
                       arup_galv_date, shot_date, paint_date, arup_paint_date
                FROM arup_ecs 
                WHERE RIGHT(assembly_code, 3) = %s
                ORDER BY assembly_code
                LIMIT 50
            """, (query.zfill(3),))  # 3자리로 패딩 (예: "27" -> "027")
        else:
            # 일반 검색 (assembly_code나 item에 포함된 경우)
            search_pattern = f"%{query}%"
            cursor.execute("""
                SELECT assembly_code, company, zone, item, weight_net,
                       fit_up_date, final_date, arup_final_date, galv_date, 
                       arup_galv_date, shot_date, paint_date, arup_paint_date
                FROM arup_ecs 
                WHERE assembly_code LIKE %s OR item LIKE %s
                ORDER BY assembly_code
                LIMIT 50
            """, (search_pattern, search_pattern))
        
        assemblies = cursor.fetchall()
        cursor.close()
        connection.close()
        
        # 각 조립품에 대해 상태 계산 (공통 함수 사용)
        processed_assemblies = []
        for assembly in assemblies:
            # dictionary를 calculate_assembly_status에 전달할 수 있도록 변환
            assembly_dict = dict(assembly)
            processed_assembly = calculate_assembly_status(assembly_dict)
            processed_assemblies.append(processed_assembly)
        
        return jsonify({
            'success': True,
            'data': processed_assemblies
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
        
        # 사용자 정보 조회
        user_info = get_user_info(current_user)
        if not user_info:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
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


@app.route('/api/inspection-requests/<int:request_id>/approve', methods=['PUT'])
@token_required
def approve_inspection_request(current_user, request_id):
    """검사신청 승인 (Level 3+ 전용)"""
    try:
        # 사용자 정보 조회
        user_info = get_user_info(current_user)
        if not user_info:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
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
        # 사용자 정보 조회
        user_info = get_user_info(current_user)
        if not user_info:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
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
        # 사용자 정보 조회
        user_info = get_user_info(current_user)
        if not user_info:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
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

def get_user_info(user_id):
    """사용자 정보 조회 함수"""
    connection = get_db_connection()
    if not connection:
        return None
    
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute("SELECT id, username, full_name, permission_level, company FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
    except:
        # company 컬럼이 없는 경우 기본 쿼리 사용
        cursor.execute("SELECT id, username, full_name, permission_level FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if user:
            user['company'] = ''
    
    cursor.close()
    connection.close()
    
    return user

def admin_required(f):
    """Admin 권한 검증 데코레이터"""
    @wraps(f)
    def decorated(current_user, *args, **kwargs):
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        cursor.execute("SELECT permission_level FROM users WHERE id = %s", (current_user,))
        user = cursor.fetchone()
        cursor.close()
        connection.close()
        
        if not user or user['permission_level'] < 5:
            return jsonify({'success': False, 'message': 'Admin 권한이 필요합니다'}), 403
        
        return f(current_user, *args, **kwargs)
    return decorated

@app.route('/api/admin/users', methods=['GET'])
@token_required
@admin_required
def get_users(current_user):
    """사용자 목록 조회 (Admin 전용)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        try:
            cursor.execute("""
                SELECT id, username, full_name, permission_level, company, is_active, created_at
                FROM users 
                ORDER BY permission_level DESC, created_at DESC
            """)
        except:
            # company 컬럼이 없는 경우
            cursor.execute("""
                SELECT id, username, full_name, permission_level, is_active, created_at
                FROM users 
                ORDER BY permission_level DESC, created_at DESC
            """)
        
        users = cursor.fetchall()
        cursor.close()
        connection.close()
        
        # 날짜 포맷팅 및 company 기본값 설정
        for user in users:
            if user['created_at']:
                user['created_at'] = user['created_at'].strftime('%Y-%m-%d %H:%M:%S')
            if 'company' not in user:
                user['company'] = ''
        
        return jsonify({
            'success': True,
            'users': users
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/admin/users', methods=['POST'])
@token_required
@admin_required
def create_user(current_user):
    """새 사용자 생성 (Admin 전용)"""
    try:
        data = request.get_json()
        username = data.get('username')
        password = data.get('password', '1234')  # 기본 비밀번호
        full_name = data.get('full_name')
        permission_level = data.get('permission_level', 1)
        company = data.get('company', '')
        
        # 비밀번호 해싱
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        if not username or not full_name:
            return jsonify({'success': False, 'message': '사용자명과 이름은 필수입니다'}), 400
        
        # 비밀번호 해시화
        password_hash = hashlib.sha256(password.encode()).hexdigest()
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor()
        
        # 중복 사용자명 확인
        cursor.execute("SELECT id FROM users WHERE username = %s", (username,))
        if cursor.fetchone():
            return jsonify({'success': False, 'message': '이미 존재하는 사용자명입니다'}), 400
        
        # 사용자 생성
        try:
            cursor.execute("""
                INSERT INTO users (username, password_hash, full_name, permission_level, company)
                VALUES (%s, %s, %s, %s, %s)
            """, (username, password_hash, full_name, permission_level, company))
        except:
            # company 컬럼이 없는 경우
            cursor.execute("""
                INSERT INTO users (username, password_hash, full_name, permission_level)
                VALUES (%s, %s, %s, %s)
            """, (username, password_hash, full_name, permission_level))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'사용자 {username}이 생성되었습니다'
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/admin/users/<int:user_id>', methods=['PUT'])
@token_required
@admin_required
def update_user(current_user, user_id):
    """사용자 정보 수정 (Admin 전용)"""
    try:
        data = request.get_json()
        full_name = data.get('full_name')
        permission_level = data.get('permission_level')
        company = data.get('company')
        is_active = data.get('is_active')
        password = data.get('password')
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor()
        
        # 사용자 존재 확인
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'success': False, 'message': '사용자를 찾을 수 없습니다'}), 404
        
        # 업데이트 필드 구성
        update_fields = []
        update_values = []
        
        if full_name is not None:
            update_fields.append("full_name = %s")
            update_values.append(full_name)
        
        if permission_level is not None:
            update_fields.append("permission_level = %s")
            update_values.append(permission_level)
        
        if password is not None:
            update_fields.append("password_hash = %s")
            password_hash = hashlib.sha256(password.encode()).hexdigest()
            update_values.append(password_hash)
        
        if company is not None:
            try:
                # company 컬럼이 있는지 확인
                cursor.execute("SHOW COLUMNS FROM users LIKE 'company'")
                if cursor.fetchone():
                    update_fields.append("company = %s")
                    update_values.append(company)
            except:
                pass
        
        if is_active is not None:
            update_fields.append("is_active = %s")
            update_values.append(is_active)
        
        if not update_fields:
            return jsonify({'success': False, 'message': '수정할 내용이 없습니다'}), 400
        
        # 업데이트 실행
        update_query = f"UPDATE users SET {', '.join(update_fields)} WHERE id = %s"
        update_values.append(user_id)
        
        cursor.execute(update_query, update_values)
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'사용자 정보가 수정되었습니다'
        })
        
    except Exception as e:
        print(f"사용자 수정 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/admin/users/<int:user_id>', methods=['DELETE'])
@token_required
@admin_required
def deactivate_user(current_user, user_id):
    """사용자 비활성화 (Admin 전용)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 사용자 존재 확인
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'success': False, 'message': '사용자를 찾을 수 없습니다'}), 404
        
        # 사용자 비활성화
        cursor.execute("UPDATE users SET is_active = FALSE WHERE id = %s", (user_id,))
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'사용자 {user["username"]}이 비활성화되었습니다'
        })
        
    except Exception as e:
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/admin/users/<int:user_id>/delete-permanently', methods=['DELETE'])
@token_required
@admin_required
def delete_user_permanently(current_user, user_id):
    """사용자 완전 삭제 (Admin 전용)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 사용자 존재 확인
        cursor.execute("SELECT username FROM users WHERE id = %s", (user_id,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'success': False, 'message': '사용자를 찾을 수 없습니다'}), 404
        
        # 자기 자신을 삭제하는 것을 방지
        if user_id == current_user:
            return jsonify({'success': False, 'message': '자기 자신을 삭제할 수 없습니다'}), 400
        
        # 사용자 완전 삭제
        cursor.execute("DELETE FROM users WHERE id = %s", (user_id,))
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'사용자 {user["username"]}이 완전히 삭제되었습니다'
        })
        
    except Exception as e:
        print(f"사용자 삭제 오류: {e}")
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

@app.route('/api/saved-list', methods=['POST'])
@token_required
def save_assembly_list(current_user):
    """사용자별 저장된 리스트에 아이템 추가"""
    try:
        data = request.get_json()
        items = data.get('items', [])
        
        if not items:
            return jsonify({'success': False, 'message': '저장할 항목이 없습니다'}), 400
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 각 항목을 저장 (중복 시 업데이트)
        saved_count = 0
        updated_count = 0
        
        for item in items:
            assembly_code = item.get('assembly_code')
            if not assembly_code:
                continue
                
            # 중복 확인
            cursor.execute("""
                SELECT id FROM user_saved_lists 
                WHERE user_id = %s AND assembly_code = %s
            """, (current_user, assembly_code))
            
            existing = cursor.fetchone()
            
            if existing:
                # 업데이트
                cursor.execute("""
                    UPDATE user_saved_lists 
                    SET assembly_data = %s, updated_at = CURRENT_TIMESTAMP
                    WHERE user_id = %s AND assembly_code = %s
                """, (json.dumps(item), current_user, assembly_code))
                updated_count += 1
            else:
                # 새로 삽입
                cursor.execute("""
                    INSERT INTO user_saved_lists (user_id, assembly_code, assembly_data)
                    VALUES (%s, %s, %s)
                """, (current_user, assembly_code, json.dumps(item)))
                saved_count += 1
        
        connection.commit()
        
        # 총 저장된 항목 수 조회
        cursor.execute("""
            SELECT COUNT(*) as total FROM user_saved_lists WHERE user_id = %s
        """, (current_user,))
        total_result = cursor.fetchone()
        total = total_result['total'] if total_result else 0
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'{saved_count}개 항목 추가, {updated_count}개 항목 업데이트',
            'saved_count': saved_count,
            'updated_count': updated_count,
            'total': total
        })
        
    except Exception as e:
        print(f"저장된 리스트 추가 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/saved-list', methods=['GET'])
@token_required
def get_saved_list(current_user):
    """사용자별 저장된 리스트 조회"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 저장된 리스트와 실시간 데이터를 JOIN으로 한번에 조회 (최적화)
        cursor.execute("""
            SELECT 
                usl.assembly_code, 
                usl.created_at as saved_at, 
                usl.updated_at,
                ae.company, 
                ae.zone, 
                ae.item, 
                ae.weight_net,
                ae.fit_up_date, 
                ae.final_date, 
                ae.arup_final_date, 
                ae.galv_date, 
                ae.arup_galv_date, 
                ae.shot_date, 
                ae.paint_date, 
                ae.arup_paint_date
            FROM user_saved_lists usl
            JOIN arup_ecs ae ON usl.assembly_code = ae.assembly_code
            WHERE usl.user_id = %s
            ORDER BY usl.updated_at DESC
        """, (current_user,))
        
        saved_items = cursor.fetchall()
        cursor.close()
        connection.close()
        
        # 실시간 데이터로 상태 계산 (JSON 파싱 없이 직접 처리)
        result_items = []
        for item in saved_items:
            try:
                # dictionary 형태로 변환
                assembly_data = dict(item)
                assembly_data['saved_at'] = item['saved_at'].strftime('%Y-%m-%d %H:%M:%S') if item['saved_at'] else ''
                assembly_data['updated_at'] = item['updated_at'].strftime('%Y-%m-%d %H:%M:%S') if item['updated_at'] else ''
                
                # 실시간 상태 계산 (최신 데이터 기반)
                assembly_data = calculate_assembly_status(assembly_data)
                
                result_items.append(assembly_data)
            except AttributeError as e:
                print(f"데이터 처리 오류: {e}")
                continue
        
        return jsonify({
            'success': True,
            'items': result_items,
            'total': len(result_items)
        })
        
    except Exception as e:
        print(f"저장된 리스트 조회 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/saved-list/<assembly_code>', methods=['DELETE'])
@token_required
def delete_saved_item(current_user, assembly_code):
    """저장된 리스트에서 특정 항목 삭제"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor()
        
        # 해당 사용자의 항목인지 확인하고 삭제
        cursor.execute("""
            DELETE FROM user_saved_lists 
            WHERE user_id = %s AND assembly_code = %s
        """, (current_user, assembly_code))
        
        if cursor.rowcount == 0:
            return jsonify({'success': False, 'message': '삭제할 항목을 찾을 수 없습니다'}), 404
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'{assembly_code} 항목이 삭제되었습니다'
        })
        
    except Exception as e:
        print(f"저장된 항목 삭제 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/saved-list/clear', methods=['DELETE'])
@token_required
def clear_saved_list(current_user):
    """사용자의 저장된 리스트 전체 삭제"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor()
        
        # 해당 사용자의 모든 저장 항목 삭제
        cursor.execute("""
            DELETE FROM user_saved_lists WHERE user_id = %s
        """, (current_user,))
        
        deleted_count = cursor.rowcount
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'{deleted_count}개 항목이 삭제되었습니다',
            'deleted_count': deleted_count
        })
        
    except Exception as e:
        print(f"저장된 리스트 전체 삭제 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

# =================================
# 검사신청 관리 API 
# =================================

@app.route('/api/inspection-management/requests', methods=['GET'])
@token_required
def get_inspection_management_requests(current_user):
    """검사신청 목록 조회"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 사용자 정보 조회
        cursor.execute("SELECT id, username, permission_level FROM users WHERE id = %s", (current_user,))
        user_info = cursor.fetchone()
        
        if not user_info:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        # Level 1 사용자는 본인 신청건만, Level 2+ 사용자는 전체 조회
        if user_info['permission_level'] == 1:
            # Level 1: 본인 신청건만 + 확정되지 않은 건과 취소된 건 제외 (한글 상태값 사용)
            query = """
                SELECT ir.*, u.username as requested_by_name
                FROM inspection_requests ir
                LEFT JOIN users u ON ir.requested_by_user_id = u.id
                WHERE ir.requested_by_user_id = %s 
                AND ir.status NOT IN ('확정됨', '취소됨')
                ORDER BY ir.created_at DESC
            """
            cursor.execute(query, (current_user,))
        else:
            # Level 2+: 전체 조회
            query = """
                SELECT ir.*, u.username as requested_by_name
                FROM inspection_requests ir
                LEFT JOIN users u ON ir.requested_by_user_id = u.id
                ORDER BY ir.created_at DESC
            """
            cursor.execute(query)
        
        requests = cursor.fetchall()
        
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'data': {
                'requests': requests,
                'user_level': user_info['permission_level']
            }
        })
        
    except Exception as e:
        print(f"검사신청 조회 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-management/requests/<int:request_id>/approve', methods=['PUT'])
@token_required
def approve_inspection_management_request(current_user, request_id):
    """검사신청 승인 (Level 2+ 권한 필요)"""
    logger.debug(f"검사신청 승인 요청: request_id={request_id}, user_id={current_user}")
    try:
        # 사용자 권한 확인
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 승인자 정보 조회
        cursor.execute("SELECT id, username, permission_level FROM users WHERE id = %s", (current_user,))
        approver = cursor.fetchone()
        
        if not approver or approver['permission_level'] < 2:
            return jsonify({'success': False, 'message': '승인 권한이 없습니다 (Level 2+ 필요)'}), 403
        
        # 검사신청 존재 및 상태 확인
        cursor.execute("SELECT * FROM inspection_requests WHERE id = %s", (request_id,))
        request_data = cursor.fetchone()
        
        if not request_data:
            logger.debug(f"검사신청을 찾을 수 없음: request_id={request_id}")
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        logger.debug(f"검사신청 현재 상태: {request_data['status']}")
        if request_data['status'] not in ['pending', '대기중']:
            logger.debug(f"승인 불가 상태: {request_data['status']}")
            return jsonify({'success': False, 'message': '대기중인 검사신청만 승인할 수 있습니다'}), 400
        
        # 승인 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = '승인됨',
                approved_by = %s,
                approved_by_name = %s,
                approved_date = CURRENT_DATE,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (current_user, approver['username'], request_id))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        logger.debug(f"검사신청 승인 완료: request_id={request_id}, approver={approver['username']}")
        return jsonify({
            'success': True,
            'message': f'검사신청이 승인되었습니다 (승인자: {approver["username"]})'
        })
        
    except Exception as e:
        logger.error(f"검사신청 승인 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-management/requests/<int:request_id>/reject', methods=['PUT'])
@token_required
def reject_inspection_management_request(current_user, request_id):
    """검사신청 거부 (Level 2+ 권한 필요)"""
    try:
        data = request.get_json()
        reject_reason = data.get('reject_reason', '거부됨')
        
        # 사용자 권한 확인
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 거부자 정보 조회
        cursor.execute("SELECT id, username, permission_level FROM users WHERE id = %s", (current_user,))
        rejecter = cursor.fetchone()
        
        if not rejecter or rejecter['permission_level'] < 2:
            return jsonify({'success': False, 'message': '거부 권한이 없습니다 (Level 2+ 필요)'}), 403
        
        # 검사신청 존재 및 상태 확인
        cursor.execute("SELECT * FROM inspection_requests WHERE id = %s", (request_id,))
        request_data = cursor.fetchone()
        
        if not request_data:
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        if request_data['status'] not in ['pending', '대기중', 'approved', '승인됨']:
            return jsonify({'success': False, 'message': '대기중이거나 승인된 검사신청만 거부할 수 있습니다'}), 400
        
        # 거부 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = '거부됨',
                reject_reason = %s,
                approved_by = %s,
                approved_by_name = %s,
                approved_date = CURRENT_DATE,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (reject_reason, current_user, rejecter['username'], request_id))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'검사신청이 거부되었습니다 (거부자: {rejecter["username"]})'
        })
        
    except Exception as e:
        print(f"검사신청 거부 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-management/requests/<int:request_id>/confirm', methods=['PUT'])
@token_required
def confirm_inspection_management_request(current_user, request_id):
    """검사신청 확정 (Level 3+ 권한 필요)"""
    try:
        data = request.get_json()
        confirmed_date = data.get('confirmed_date')
        
        if not confirmed_date:
            return jsonify({'success': False, 'message': '확정 날짜를 입력해주세요'}), 400
        
        # 사용자 권한 확인
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 확정자 정보 조회
        cursor.execute("SELECT id, username, permission_level FROM users WHERE id = %s", (current_user,))
        confirmer = cursor.fetchone()
        
        if not confirmer or confirmer['permission_level'] < 3:
            return jsonify({'success': False, 'message': '확정 권한이 없습니다 (Level 3+ 필요)'}), 403
        
        # 검사신청 존재 및 상태 확인
        cursor.execute("SELECT * FROM inspection_requests WHERE id = %s", (request_id,))
        request_data = cursor.fetchone()
        
        if not request_data:
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        if request_data['status'] not in ['approved', '승인됨']:
            return jsonify({'success': False, 'message': '승인된 검사신청만 확정할 수 있습니다'}), 400
        
        # 확정 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = '확정됨',
                confirmed_by = %s,
                confirmed_by_name = %s,
                confirmed_date = %s,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (current_user, confirmer['username'], confirmed_date, request_id))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'검사신청이 확정되었습니다 (확정자: {confirmer["username"]})'
        })
        
    except Exception as e:
        print(f"검사신청 확정 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-management/requests/<int:request_id>/cancel', methods=['PUT'])
@token_required
def cancel_inspection_management_request(current_user, request_id):
    """검사신청 취소 (본인 신청건만, 대기중 상태만)"""
    try:
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 사용자 정보 조회
        cursor.execute("SELECT id, username FROM users WHERE id = %s", (current_user,))
        user_info = cursor.fetchone()
        
        if not user_info:
            return jsonify({'success': False, 'message': '사용자 정보를 찾을 수 없습니다'}), 404
        
        # 검사신청 존재 및 권한 확인
        cursor.execute("SELECT * FROM inspection_requests WHERE id = %s", (request_id,))
        request_data = cursor.fetchone()
        
        if not request_data:
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        # 본인 신청건인지 확인
        if request_data['requested_by_user_id'] != current_user:
            return jsonify({'success': False, 'message': '본인이 신청한 검사신청만 취소할 수 있습니다'}), 403
        
        # 대기중 상태인지 확인
        if request_data['status'] not in ['pending', '대기중']:
            return jsonify({'success': False, 'message': '대기중인 검사신청만 취소할 수 있습니다'}), 400
        
        # 취소 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = '취소됨',
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (request_id,))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'검사신청이 취소되었습니다 (신청자: {user_info["username"]})'
        })
        
    except Exception as e:
        print(f"검사신청 취소 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-management/requests/<int:request_id>', methods=['DELETE'])
@token_required
def delete_inspection_management_request(current_user, request_id):
    """검사신청 삭제 (Level 3+ 권한 필요)"""
    try:
        # 사용자 권한 확인
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 삭제자 정보 조회
        cursor.execute("SELECT id, username, permission_level FROM users WHERE id = %s", (current_user,))
        deleter = cursor.fetchone()
        
        if not deleter or deleter['permission_level'] < 3:
            return jsonify({'success': False, 'message': '삭제 권한이 없습니다 (Level 3+ 필요)'}), 403
        
        # 검사신청 존재 확인
        cursor.execute("SELECT assembly_code FROM inspection_requests WHERE id = %s", (request_id,))
        request_data = cursor.fetchone()
        
        if not request_data:
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        # 삭제 처리
        cursor.execute("DELETE FROM inspection_requests WHERE id = %s", (request_id,))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'검사신청이 삭제되었습니다 (조립품: {request_data["assembly_code"]}, 삭제자: {deleter["username"]})'
        })
        
    except Exception as e:
        print(f"검사신청 삭제 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

if __name__ == '__main__':
    print("DSHI Field Pad Server starting...")
    print(f"Server URL: http://{SERVER_CONFIG['host']}:{SERVER_CONFIG['port']}")
    app.run(**SERVER_CONFIG)
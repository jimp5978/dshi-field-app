"""
검사신청 관련 블루프린트
"""
import datetime
import logging
from flask import Blueprint, request, jsonify
from utils.database import get_db_connection
from utils.auth_utils import token_required, get_user_info

inspection_bp = Blueprint('inspection', __name__)
logger = logging.getLogger(__name__)

@inspection_bp.route('/inspection-requests', methods=['POST'])
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

@inspection_bp.route('/inspection-requests/<int:request_id>/approve', methods=['PUT'])
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

@inspection_bp.route('/inspection-requests/<int:request_id>/confirm', methods=['PUT'])
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

@inspection_bp.route('/inspection-requests/<int:request_id>', methods=['DELETE'])
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

@inspection_bp.route('/inspection-management/requests', methods=['GET'])
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

@inspection_bp.route('/inspection-management/requests/<int:request_id>/approve', methods=['PUT'])
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

@inspection_bp.route('/inspection-management/requests/<int:request_id>/reject', methods=['PUT'])
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

@inspection_bp.route('/inspection-management/requests/<int:request_id>/confirm', methods=['PUT'])
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

@inspection_bp.route('/inspection-management/requests/<int:request_id>/cancel', methods=['PUT'])
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

@inspection_bp.route('/inspection-management/requests/<int:request_id>', methods=['DELETE'])
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
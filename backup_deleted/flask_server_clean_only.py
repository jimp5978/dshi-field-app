#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DSHI Field Pad - Flask API Server (Clean Version)
검사신청 관리 시스템을 위한 API 서버
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))

from flask import Flask, request, jsonify
from flask_cors import CORS
import mysql.connector
from mysql.connector import Error
import hashlib
import jwt
import datetime
from functools import wraps
import json

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

# JWT 토큰 데코레이터
def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(' ')[1]
        
        if not token:
            return jsonify({'success': False, 'message': '토큰이 없습니다'}), 401
        
        try:
            data = jwt.decode(token, app.config['SECRET_KEY'], algorithms=["HS256"])
            current_user = data['user_id']
        except:
            return jsonify({'success': False, 'message': '토큰이 유효하지 않습니다'}), 401
        
        return f(current_user, *args, **kwargs)
    
    return decorated

# =================================
# 검사신청 관리 API 
# =================================

@app.route('/api/inspection-requests', methods=['GET'])
@token_required
def get_inspection_requests_new(current_user):
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
            # Level 1: 본인 신청건만 + 확정되지 않은 건만 표시
            query = """
                SELECT ir.*, u.username as requested_by_name
                FROM inspection_requests ir
                LEFT JOIN users u ON ir.requested_by_user_id = u.id
                WHERE ir.requested_by_user_id = %s 
                AND ir.status != 'confirmed'
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

@app.route('/api/inspection-requests/<int:request_id>/approve', methods=['PUT'])
@token_required
def approve_inspection_request(current_user, request_id):
    """검사신청 승인 (Level 2+ 권한 필요)"""
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
            return jsonify({'success': False, 'message': '검사신청을 찾을 수 없습니다'}), 404
        
        if request_data['status'] != 'pending':
            return jsonify({'success': False, 'message': '대기중인 검사신청만 승인할 수 있습니다'}), 400
        
        # 승인 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = 'approved',
                approved_by = %s,
                approved_by_name = %s,
                approved_date = CURRENT_DATE,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = %s
        """, (current_user, approver['username'], request_id))
        
        connection.commit()
        cursor.close()
        connection.close()
        
        return jsonify({
            'success': True,
            'message': f'검사신청이 승인되었습니다 (승인자: {approver["username"]})'
        })
        
    except Exception as e:
        print(f"검사신청 승인 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500

@app.route('/api/inspection-requests/<int:request_id>/reject', methods=['PUT'])
@token_required
def reject_inspection_request(current_user, request_id):
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
        
        if request_data['status'] not in ['pending', 'approved']:
            return jsonify({'success': False, 'message': '대기중이거나 승인된 검사신청만 거부할 수 있습니다'}), 400
        
        # 거부 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = 'rejected',
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

@app.route('/api/inspection-requests/<int:request_id>/confirm', methods=['PUT'])
@token_required
def confirm_inspection_request(current_user, request_id):
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
        
        if request_data['status'] != 'approved':
            return jsonify({'success': False, 'message': '승인된 검사신청만 확정할 수 있습니다'}), 400
        
        # 확정 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = 'confirmed',
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

@app.route('/api/inspection-requests/<int:request_id>/cancel', methods=['PUT'])
@token_required
def cancel_inspection_request(current_user, request_id):
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
        if request_data['status'] != 'pending':
            return jsonify({'success': False, 'message': '대기중인 검사신청만 취소할 수 있습니다'}), 400
        
        # 취소 처리
        cursor.execute("""
            UPDATE inspection_requests 
            SET status = 'cancelled',
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

@app.route('/api/inspection-requests/<int:request_id>', methods=['DELETE'])
@token_required
def delete_inspection_request(current_user, request_id):
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

# 헬스체크 엔드포인트
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.datetime.now().isoformat(),
        'version': 'inspection-management-v1.0'
    })

if __name__ == '__main__':
    print("DSHI Field Pad Server starting...")
    print(f"Server URL: http://{SERVER_CONFIG['host']}:{SERVER_CONFIG['port']}")
    app.run(**SERVER_CONFIG)
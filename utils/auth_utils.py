"""
인증 관련 유틸리티 함수들
"""
import jwt
from flask import request, jsonify, current_app
from functools import wraps
from .database import get_db_connection

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
            
            data = jwt.decode(token, current_app.config['SECRET_KEY'], algorithms=['HS256'])
            # Excel 업로드 API는 전체 JWT 데이터가 필요하므로 함수별로 구분
            if f.__name__ in ['upload_excel', 'upload_assembly_codes']:
                current_user = data  # 전체 JWT 데이터 전달
            else:
                current_user = data['user_id']  # 기존 방식 유지
        except:
            return jsonify({'message': '토큰이 유효하지 않습니다'}), 401
        
        return f(current_user, *args, **kwargs)
    return decorated

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
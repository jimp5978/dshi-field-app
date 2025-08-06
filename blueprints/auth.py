"""
인증 관련 블루프린트
"""
import hashlib
import jwt
import datetime
from flask import Blueprint, request, jsonify, current_app
from utils.database import get_db_connection

auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login', methods=['POST'])
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
            }, current_app.config['SECRET_KEY'], algorithm='HS256')
            
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
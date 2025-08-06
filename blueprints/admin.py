"""
관리자 관련 블루프린트
"""
import hashlib
from flask import Blueprint, request, jsonify
from utils.database import get_db_connection
from utils.auth_utils import token_required, admin_required

admin_bp = Blueprint('admin', __name__)

@admin_bp.route('/admin/users', methods=['GET'])
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

@admin_bp.route('/admin/users', methods=['POST'])
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

@admin_bp.route('/admin/users/<int:user_id>', methods=['PUT'])
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

@admin_bp.route('/admin/users/<int:user_id>', methods=['DELETE'])
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

@admin_bp.route('/admin/users/<int:user_id>/delete-permanently', methods=['DELETE'])
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
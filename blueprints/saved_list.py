"""
저장된 리스트 관련 블루프린트
"""
import json
from flask import Blueprint, request, jsonify
from utils.database import get_db_connection
from utils.auth_utils import token_required
from utils.assembly_utils import calculate_assembly_status

saved_list_bp = Blueprint('saved_list', __name__)

@saved_list_bp.route('/saved-list', methods=['POST'])
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

@saved_list_bp.route('/saved-list', methods=['GET'])
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
                ae.weight_gross,
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

@saved_list_bp.route('/saved-list/<assembly_code>', methods=['DELETE'])
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

@saved_list_bp.route('/saved-list/clear', methods=['DELETE'])
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
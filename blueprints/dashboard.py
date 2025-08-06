"""
대시보드 관련 블루프린트
"""
import datetime
from flask import Blueprint, jsonify
from utils.database import get_db_connection
from utils.auth_utils import token_required, get_user_info

dashboard_bp = Blueprint('dashboard', __name__)

@dashboard_bp.route('/dashboard-data', methods=['GET'])
@token_required
def get_dashboard_data(current_user):
    """대시보드 데이터 제공 API (Level 3+ 권한 필요)"""
    try:
        # 사용자 권한 확인
        user_info = get_user_info(current_user)
        if not user_info or user_info['permission_level'] < 3:
            return jsonify({'success': False, 'message': '대시보드 접근 권한이 없습니다 (Level 3+ 필요)'}), 403
        
        connection = get_db_connection()
        if not connection:
            return jsonify({'success': False, 'message': '데이터베이스 연결 실패'}), 500
        
        cursor = connection.cursor(dictionary=True)
        
        # 1. 전체 통계
        cursor.execute("""
            SELECT 
                COUNT(*) as total_assemblies,
                SUM(weight_gross) as total_weight
            FROM arup_ecs 
            WHERE weight_gross IS NOT NULL
        """)
        overall_stats = cursor.fetchone()
        
        # 2. 8단계 공정별 완료율 (중량 기준)
        processes = [
            ('FIT_UP', 'fit_up_date'),
            ('FINAL', 'final_date'),
            ('ARUP_FINAL', 'arup_final_date'),
            ('GALV', 'galv_date'),
            ('ARUP_GALV', 'arup_galv_date'),
            ('SHOT', 'shot_date'),
            ('PAINT', 'paint_date'),
            ('ARUP_PAINT', 'arup_paint_date')
        ]
        
        process_completion = {}
        for process_name, date_column in processes:
            cursor.execute(f"""
                SELECT COALESCE(SUM(weight_gross), 0) as completed_weight
                FROM arup_ecs 
                WHERE {date_column} IS NOT NULL 
                AND {date_column} != '1900-01-01'
                AND weight_gross IS NOT NULL
            """)
            result = cursor.fetchone()
            completed_weight = result['completed_weight']
            percentage = round((completed_weight / overall_stats['total_weight']) * 100, 1) if overall_stats['total_weight'] > 0 else 0
            process_completion[process_name] = percentage
        
        # 3. ITEM별 공정률 (BEAM/POST 탭)
        item_process_completion = {}
        for item_type in ['BEAM', 'POST']:
            item_process_completion[item_type] = {}
            
            # 해당 ITEM의 총 중량 계산
            cursor.execute("""
                SELECT COALESCE(SUM(weight_gross), 0) as item_total_weight
                FROM arup_ecs 
                WHERE item = %s AND weight_gross IS NOT NULL
            """, (item_type,))
            item_total = cursor.fetchone()['item_total_weight']
            
            # 각 공정별 완료율 계산
            for process_name, date_column in processes:
                cursor.execute(f"""
                    SELECT COALESCE(SUM(weight_gross), 0) as completed_weight
                    FROM arup_ecs 
                    WHERE item = %s 
                    AND {date_column} IS NOT NULL 
                    AND {date_column} != '1900-01-01'
                    AND weight_gross IS NOT NULL
                """, (item_type,))
                result = cursor.fetchone()
                completed_weight = result['completed_weight']
                percentage = round((completed_weight / item_total) * 100, 1) if item_total > 0 else 0
                item_process_completion[item_type][process_name] = percentage
        
        # 4. 업체별 분포 (중량 기준)
        cursor.execute("""
            SELECT 
                company,
                COUNT(*) as count,
                SUM(weight_gross) as total_weight,
                ROUND((SUM(weight_gross) / %s) * 100, 1) as percentage
            FROM arup_ecs 
            WHERE weight_gross IS NOT NULL AND company IS NOT NULL
            GROUP BY company
            ORDER BY total_weight DESC
        """, (overall_stats['total_weight'],))
        company_distribution = cursor.fetchall()
        
        # 5. 전체 진행률 계산 (ARUP_PAINT 완료된 중량 기준)
        cursor.execute("""
            SELECT COALESCE(SUM(weight_gross), 0) as completed_weight
            FROM arup_ecs 
            WHERE arup_paint_date IS NOT NULL 
            AND arup_paint_date != '1900-01-01'
            AND weight_gross IS NOT NULL
        """)
        completed_total = cursor.fetchone()['completed_weight']
        overall_progress = round((completed_total / overall_stats['total_weight']) * 100, 1) if overall_stats['total_weight'] > 0 else 0
        
        cursor.close()
        connection.close()
        
        # 6. 데이터 소스 정보
        data_source = {
            'updated_at': datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
            'total_assemblies': overall_stats['total_assemblies'],
            'total_weight_tons': round(overall_stats['total_weight'] / 1000, 1) if overall_stats['total_weight'] else 0
        }
        
        # 최종 대시보드 데이터 구성
        dashboard_data = {
            'overall_stats': {
                'total_assemblies': overall_stats['total_assemblies'],
                'total_weight': round(overall_stats['total_weight'], 1) if overall_stats['total_weight'] else 0,
                'total_weight_tons': data_source['total_weight_tons'],
                'overall_progress': overall_progress
            },
            'process_completion': process_completion,
            'item_process_completion': item_process_completion,
            'company_distribution': company_distribution,
            'data_source': data_source
        }
        
        return jsonify({
            'success': True,
            'data': dashboard_data
        })
        
    except Exception as e:
        print(f"Dashboard 데이터 조회 오류: {e}")
        return jsonify({'success': False, 'message': f'서버 오류: {str(e)}'}), 500
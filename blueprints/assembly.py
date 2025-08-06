"""
조립품 관련 블루프린트
"""
import datetime
from flask import Blueprint, request, jsonify
from utils.database import get_db_connection
from utils.assembly_utils import calculate_assembly_status

assembly_bp = Blueprint('assembly', __name__)

@assembly_bp.route('/assemblies', methods=['GET'])
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

@assembly_bp.route('/assemblies/search', methods=['GET'])
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
                SELECT assembly_code, company, zone, item, weight_gross,
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
                SELECT assembly_code, company, zone, item, weight_gross,
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
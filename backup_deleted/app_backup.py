from flask import Flask, request, jsonify
import pymysql.cursors
from datetime import datetime, date

app = Flask(__name__)

# --- MySQL 접속 설정 ---
MYSQL_HOST = 'localhost'
MYSQL_USER = 'field_app_user'
MYSQL_PASSWORD = 'F!eldApp_Pa$$w0rd_2025#'
MYSQL_DB = 'field_app_db'
# -----------------------

def get_db():
    return pymysql.connect(
        host=MYSQL_HOST,
        user=MYSQL_USER,
        password=MYSQL_PASSWORD,
        database=MYSQL_DB,
        cursorclass=pymysql.cursors.DictCursor
    )

# ASSEMBLY 검색 API (수정된 버전)
@app.route('/api/search_assembly', methods=['GET'])
def search_assembly():
    query = request.args.get('query', '')
    print(f"\n[Flask] 검색 쿼리 수신: {query}")
    conn = get_db()
    cursor = conn.cursor()

    try:
        cursor.execute("""
            SELECT 
                assembly_code, zone, item, 
                fit_up_date, nde_date, vidi_date, galv_date, shot_date, paint_date, packing_date
            FROM assembly_items 
            WHERE assembly_code LIKE %s OR zone LIKE %s OR item LIKE %s
        """, (f'%{query}%', f'%{query}%', f'%{query}%'))

        rows = cursor.fetchall()
        print(f"[Flask] DB에서 조회된 raw 데이터 행 수: {len(rows)}")

        cursor.execute("SELECT process_name FROM process_definitions ORDER BY process_order ASC")
        process_steps_db = cursor.fetchall()
        process_steps = [p['process_name'] for p in process_steps_db]
        print(f"[Flask] 공정 순서: {process_steps}")

        # 공정 이름과 데이터베이스 컬럼 매핑
        process_column_mapping = {
            'Fit-up': 'fit_up_date',
            'NDE': 'nde_date',
            'VIDI': 'vidi_date',
            'GALV': 'galv_date',
            'SHOT': 'shot_date',
            'PAINT': 'paint_date',
            'PACKING': 'packing_date'
        }

        results = []
        for item in rows:
            last_completed_step = None
            last_completion_date_obj = None

            print(f"[Flask] 처리 중인 ASSEMBLY: {item['assembly_code']}")
            
            for step in process_steps:
                date_col_name = process_column_mapping.get(step)
                if not date_col_name:
                    print(f"[Flask] 경고: {step} 공정의 컬럼 매핑을 찾을 수 없습니다.")
                    continue
                    
                date_value = item.get(date_col_name)
                print(f"[Flask]   {step} ({date_col_name}): {date_value}")

                if date_value and isinstance(date_value, date):
                    current_date = datetime(date_value.year, date_value.month, date_value.day)
                    if last_completion_date_obj is None or current_date > last_completion_date_obj:
                        last_completion_date_obj = current_date
                        last_completed_step = step
                        print(f"[Flask]   → 새로운 마지막 단계: {step} ({current_date.strftime('%Y-%m-%d')})")

            print(f"[Flask] 최종 마지막 단계: {last_completed_step} ({last_completion_date_obj.strftime('%Y-%m-%d') if last_completion_date_obj else 'None'})")

            item_for_flutter = {
                'ASSEMBLY': item['assembly_code'],
                'ZONE': item['zone'],
                'ITEM': item['item'],
                'Fit-up_date': item['fit_up_date'].strftime('%Y-%m-%d') if isinstance(item['fit_up_date'], date) else None,
                'NDE_date': item['nde_date'].strftime('%Y-%m-%d') if isinstance(item['nde_date'], date) else None,
                'VIDI_date': item['vidi_date'].strftime('%Y-%m-%d') if isinstance(item['vidi_date'], date) else None,
                'GALV_date': item['galv_date'].strftime('%Y-%m-%d') if isinstance(item['galv_date'], date) else None,
                'SHOT_date': item['shot_date'].strftime('%Y-%m-%d') if isinstance(item['shot_date'], date) else None,
                'PAINT_date': item['paint_date'].strftime('%Y-%m-%d') if isinstance(item['paint_date'], date) else None,
                'PACKING_date': item['packing_date'].strftime('%Y-%m-%d') if isinstance(item['packing_date'], date) else None,
                '마지막 단계': last_completed_step,
                '마지막 단계 날짜': last_completion_date_obj.strftime('%Y-%m-%d') if last_completion_date_obj else None
            }

            results.append(item_for_flutter)

        return jsonify(results)

    except Exception as e:
        print(f"[Flask] 검색 오류: {e}")
        return jsonify({'error': f'서버 오류: {e}'}), 500
    finally:
        conn.close()

# 공정 업데이트 API
@app.route('/api/update_process', methods=['POST'])
def update_process():
    data = request.get_json()
    assembly_code = data.get('assembly_code')
    process_name = data.get('process_name')

    print(f"\n[Flask] 공정 업데이트 요청: ASSEMBLY={assembly_code}, PROCESS={process_name}")

    if not assembly_code or not process_name:
        return jsonify({'error': 'ASSEMBLY 코드와 공정 이름이 필요합니다.'}), 400

    conn = get_db()
    cursor = conn.cursor()

    try:
        cursor.execute("SELECT process_name, process_order FROM process_definitions ORDER BY process_order ASC")
        process_definitions = cursor.fetchall()
        process_order_map = {p['process_name']: p['process_order'] for p in process_definitions}
        process_names_ordered = [p['process_name'] for p in process_definitions]

        if process_name not in process_order_map:
            return jsonify({'error': '유효하지 않은 공정 이름입니다.'}), 400

        date_col_name = f'{process_name.lower()}_date'

        # 현재 공정 상태 확인
        cursor.execute(f'SELECT {date_col_name} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
        current_status = cursor.fetchone()
        if current_status and current_status[date_col_name] is not None:
            return jsonify({'error': f'{process_name} 공정은 이미 완료되었습니다.'}), 400

        # 이전 공정 확인
        current_order = process_order_map[process_name]
        if current_order > 1:
            prev_name = process_names_ordered[current_order - 2]
            prev_col = f'{prev_name.lower()}_date'
            cursor.execute(f'SELECT {prev_col} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
            prev_status = cursor.fetchone()
            if not prev_status or prev_status[prev_col] is None:
                return jsonify({'error': f'이전 공정 ({prev_name})이 완료되지 않았습니다.'}), 400

        today = datetime.now().strftime('%Y-%m-%d')
        cursor.execute(f'UPDATE assembly_items SET {date_col_name} = %s WHERE assembly_code = %s', (today, assembly_code))
        conn.commit()
        return jsonify({'message': f'{process_name} 공정 완료 처리됨.'}), 200

    except Exception as e:
        conn.rollback()
        print(f"[Flask] 업데이트 오류: {e}")
        return jsonify({'error': f'데이터베이스 오류: {e}'}), 500
    finally:
        conn.close()
# app.py에 추가할 배치 처리 API 엔드포인트

# 배치 공정 업데이트 API
@app.route('/api/batch_update_process', methods=['POST'])
def batch_update_process():
    data = request.get_json()
    assembly_codes = data.get('assembly_codes', [])
    process_name = data.get('process_name')

    print(f"\n[Flask] 배치 공정 업데이트 요청: ASSEMBLIES={assembly_codes}, PROCESS={process_name}")

    if not assembly_codes or not process_name:
        return jsonify({'error': 'ASSEMBLY 코드 목록과 공정 이름이 필요합니다.'}), 400

    conn = get_db()
    cursor = conn.cursor()

    try:
        cursor.execute("SELECT process_name, process_order FROM process_definitions ORDER BY process_order ASC")
        process_definitions = cursor.fetchall()
        process_order_map = {p['process_name']: p['process_order'] for p in process_definitions}
        process_names_ordered = [p['process_name'] for p in process_definitions]

        if process_name not in process_order_map:
            return jsonify({'error': '유효하지 않은 공정 이름입니다.'}), 400

        date_col_name = f'{process_name.lower()}_date'
        current_order = process_order_map[process_name]
        
        # 각 ASSEMBLY별로 검증 및 업데이트
        success_items = []
        failed_items = []
        
        for assembly_code in assembly_codes:
            try:
                # 1. 현재 공정 상태 확인
                cursor.execute(f'SELECT {date_col_name} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
                current_status = cursor.fetchone()
                
                if not current_status:
                    failed_items.append({'assembly': assembly_code, 'reason': 'ASSEMBLY 코드를 찾을 수 없습니다.'})
                    continue
                    
                if current_status[date_col_name] is not None:
                    failed_items.append({'assembly': assembly_code, 'reason': f'{process_name} 공정이 이미 완료되었습니다.'})
                    continue

                # 2. 이전 공정 완료 여부 확인
                if current_order > 1:
                    prev_name = process_names_ordered[current_order - 2]
                    prev_col = f'{prev_name.lower()}_date'
                    cursor.execute(f'SELECT {prev_col} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
                    prev_status = cursor.fetchone()
                    
                    if not prev_status or prev_status[prev_col] is None:
                        failed_items.append({'assembly': assembly_code, 'reason': f'이전 공정 ({prev_name})이 완료되지 않았습니다.'})
                        continue

                # 3. 업데이트 실행
                today = datetime.now().strftime('%Y-%m-%d')
                cursor.execute(f'UPDATE assembly_items SET {date_col_name} = %s WHERE assembly_code = %s', (today, assembly_code))
                success_items.append(assembly_code)
                
            except Exception as item_error:
                failed_items.append({'assembly': assembly_code, 'reason': f'처리 오류: {str(item_error)}'})
                print(f"[Flask] {assembly_code} 처리 오류: {item_error}")

        # 변경사항 커밋
        if success_items:
            conn.commit()
            print(f"[Flask] 배치 업데이트 성공: {len(success_items)}개 항목")
        else:
            conn.rollback()
            print(f"[Flask] 배치 업데이트 실패: 성공한 항목 없음")

        # 결과 반환
        result = {
            'success_count': len(success_items),
            'failed_count': len(failed_items),
            'success_items': success_items,
            'failed_items': failed_items,
            'message': f'{process_name} 공정 배치 업데이트 완료'
        }
        
        if failed_items:
            result['warning'] = f'{len(failed_items)}개 항목 처리 실패'

        return jsonify(result), 200

    except Exception as e:
        conn.rollback()
        print(f"[Flask] 배치 업데이트 오류: {e}")
        return jsonify({'error': f'데이터베이스 오류: {e}'}), 500
    finally:
        conn.close()


# 공정 상태 요약 API (선택사항 - 대시보드용)
@app.route('/api/process_summary', methods=['GET'])
def process_summary():
    """전체 공정 진행 상황 요약"""
    conn = get_db()
    cursor = conn.cursor()

    try:
        # 각 공정별 완료 상황 통계
        cursor.execute("""
            SELECT 
                SUM(CASE WHEN fit_up_date IS NOT NULL THEN 1 ELSE 0 END) as fit_up_completed,
                SUM(CASE WHEN nde_date IS NOT NULL THEN 1 ELSE 0 END) as nde_completed,
                SUM(CASE WHEN vidi_date IS NOT NULL THEN 1 ELSE 0 END) as vidi_completed,
                SUM(CASE WHEN galv_date IS NOT NULL THEN 1 ELSE 0 END) as galv_completed,
                SUM(CASE WHEN shot_date IS NOT NULL THEN 1 ELSE 0 END) as shot_completed,
                SUM(CASE WHEN paint_date IS NOT NULL THEN 1 ELSE 0 END) as paint_completed,
                SUM(CASE WHEN packing_date IS NOT NULL THEN 1 ELSE 0 END) as packing_completed,
                COUNT(*) as total_items
            FROM assembly_items
        """)
        
        summary = cursor.fetchone()
        
        # 결과 포맷팅
        result = {
            'total_items': summary['total_items'],
            'process_progress': {
                'Fit-up': summary['fit_up_completed'],
                'NDE': summary['nde_completed'],
                'VIDI': summary['vidi_completed'],
                'GALV': summary['galv_completed'],
                'SHOT': summary['shot_completed'],
                'PAINT': summary['paint_completed'],
                'PACKING': summary['packing_completed']
            }
        }
        
        return jsonify(result), 200

    except Exception as e:
        print(f"[Flask] 공정 요약 오류: {e}")
        return jsonify({'error': f'서버 오류: {e}'}), 500
    finally:
        conn.close()

# 배치 공정 업데이트 API - app.py에 추가
@app.route('/api/batch_update_process', methods=['POST'])
def batch_update_process():
    data = request.get_json()
    assembly_codes = data.get('assembly_codes', [])
    process_name = data.get('process_name')

    print(f"\n[Flask] 배치 공정 업데이트 요청: ASSEMBLIES={assembly_codes}, PROCESS={process_name}")

    if not assembly_codes or not process_name:
        return jsonify({'error': 'ASSEMBLY 코드 목록과 공정 이름이 필요합니다.'}), 400

    conn = get_db()
    cursor = conn.cursor()

    try:
        cursor.execute("SELECT process_name, process_order FROM process_definitions ORDER BY process_order ASC")
        process_definitions = cursor.fetchall()
        process_order_map = {p['process_name']: p['process_order'] for p in process_definitions}
        process_names_ordered = [p['process_name'] for p in process_definitions]

        if process_name not in process_order_map:
            return jsonify({'error': '유효하지 않은 공정 이름입니다.'}), 400

        # 공정 이름과 데이터베이스 컬럼 매핑
        process_column_mapping = {
            'Fit-up': 'fit_up_date',
            'NDE': 'nde_date',
            'VIDI': 'vidi_date',
            'GALV': 'galv_date',
            'SHOT': 'shot_date',
            'PAINT': 'paint_date',
            'PACKING': 'packing_date'
        }

        date_col_name = process_column_mapping.get(process_name)
        if not date_col_name:
            return jsonify({'error': f'{process_name} 공정의 컬럼 매핑을 찾을 수 없습니다.'}), 400

        current_order = process_order_map[process_name]
        
        # 각 ASSEMBLY별로 검증 및 업데이트
        success_items = []
        failed_items = []
        
        for assembly_code in assembly_codes:
            try:
                print(f"[Flask] 처리 중: {assembly_code}")
                
                # 1. 현재 공정 상태 확인
                cursor.execute(f'SELECT {date_col_name} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
                current_status = cursor.fetchone()
                
                if not current_status:
                    failed_items.append({'assembly': assembly_code, 'reason': 'ASSEMBLY 코드를 찾을 수 없습니다.'})
                    continue
                    
                if current_status[date_col_name] is not None:
                    failed_items.append({'assembly': assembly_code, 'reason': f'{process_name} 공정이 이미 완료되었습니다.'})
                    continue

                # 2. 이전 공정 완료 여부 확인
                if current_order > 1:
                    prev_name = process_names_ordered[current_order - 2]
                    prev_col = process_column_mapping.get(prev_name)
                    if prev_col:
                        cursor.execute(f'SELECT {prev_col} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
                        prev_status = cursor.fetchone()
                        
                        if not prev_status or prev_status[prev_col] is None:
                            failed_items.append({'assembly': assembly_code, 'reason': f'이전 공정 ({prev_name})이 완료되지 않았습니다.'})
                            continue

                # 3. 업데이트 실행
                today = datetime.now().strftime('%Y-%m-%d')
                cursor.execute(f'UPDATE assembly_items SET {date_col_name} = %s WHERE assembly_code = %s', (today, assembly_code))
                success_items.append(assembly_code)
                print(f"[Flask] {assembly_code} 업데이트 성공: {process_name} = {today}")
                
            except Exception as item_error:
                failed_items.append({'assembly': assembly_code, 'reason': f'처리 오류: {str(item_error)}'})
                print(f"[Flask] {assembly_code} 처리 오류: {item_error}")

        # 변경사항 커밋
        if success_items:
            conn.commit()
            print(f"[Flask] 배치 업데이트 성공: {len(success_items)}개 항목")
        else:
            conn.rollback()
            print(f"[Flask] 배치 업데이트 실패: 성공한 항목 없음")

        # 결과 반환
        result = {
            'success_count': len(success_items),
            'failed_count': len(failed_items),
            'success_items': success_items,
            'failed_items': failed_items,
            'message': f'{process_name} 공정 배치 업데이트 완료'
        }
        
        return jsonify(result), 200

    except Exception as e:
        conn.rollback()
        print(f"[Flask] 배치 업데이트 오류: {e}")
        return jsonify({'error': f'데이터베이스 오류: {e}'}), 500
    finally:
        conn.close()

# Flask 앱 실행
if __name__ == '__main__':
    print("✅ Flask 애플리케이션 실행 시작")
    app.run(host='0.0.0.0', port=5000, debug=True)

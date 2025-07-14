from flask import Flask, request, jsonify
import pymysql.cursors
from datetime import datetime, date

app = Flask(__name__)

# --- MySQL 접속 설정 ---
MYSQL_HOST = 'localhost'
MYSQL_USER = 'field_app_user'
MYSQL_PASSWORD = 'F!eldApp_Pa$w0rd_2025#'
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

# 로그인 API
@app.route('/api/login', methods=['POST'])
def login():
    data = request.get_json()
    username = data.get('username')
    password_hash = data.get('password_hash')
    
    if not username or not password_hash:
        return jsonify({
            'success': False,
            'message': '아이디와 비밀번호를 입력해주세요'
        })
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # 사용자 정보 조회
        cursor.execute("""
            SELECT id, username, full_name, permission_level, is_active
            FROM users 
            WHERE username = %s AND password_hash = %s AND is_active = 1
        """, (username, password_hash))
        
        user = cursor.fetchone()
        
        if user:
            return jsonify({
                'success': True,
                'message': '로그인 성공',
                'user': {
                    'id': user['id'],
                    'username': user['username'],
                    'full_name': user['full_name'],
                    'permission_level': user['permission_level']
                }
            })
        else:
            return jsonify({
                'success': False,
                'message': '아이디 또는 비밀번호가 잘못되었습니다'
            })
            
    except Exception as e:
        print(f"[Flask] 로그인 오류: {e}")
        return jsonify({
            'success': False,
            'message': '서버 오류가 발생했습니다'
        })
    finally:
        conn.close()

# 롤백 사유 목록 조회 API
@app.route('/api/rollback_reasons', methods=['GET'])
def get_rollback_reasons():
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        cursor.execute("""
            SELECT id, reason_text, display_order
            FROM rollback_reasons
            ORDER BY display_order ASC
        """)
        
        reasons = cursor.fetchall()
        
        return jsonify({
            'success': True,
            'reasons': reasons
        })
        
    except Exception as e:
        print(f"[Flask] 롤백 사유 조회 오류: {e}")
        return jsonify({
            'success': False,
            'message': '롤백 사유 조회 실패'
        })
    finally:
        conn.close()

# ASSEMBLY 검색 API
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

            for step in process_steps:
                date_col_name = process_column_mapping.get(step)
                if not date_col_name:
                    continue
                    
                date_value = item.get(date_col_name)

                if date_value and isinstance(date_value, date):
                    current_date = datetime(date_value.year, date_value.month, date_value.day)
                    if last_completion_date_obj is None or current_date > last_completion_date_obj:
                        last_completion_date_obj = current_date
                        last_completed_step = step

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

# 단일 공정 업데이트 API
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

        # 현재 공정 상태 확인
        cursor.execute(f'SELECT {date_col_name} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
        current_status = cursor.fetchone()
        if current_status and current_status[date_col_name] is not None:
            return jsonify({'error': f'{process_name} 공정은 이미 완료되었습니다.'}), 400

        # 이전 공정 확인
        current_order = process_order_map[process_name]
        if current_order > 1:
            prev_name = process_names_ordered[current_order - 2]
            prev_col = process_column_mapping.get(prev_name)
            if prev_col:
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

# 공정 롤백 API
@app.route('/api/rollback_process', methods=['POST'])
def rollback_process():
    data = request.get_json()
    assembly_code = data.get('assembly_code')
    process_name = data.get('process_name')
    rollback_reason_id = data.get('rollback_reason_id')
    notes = data.get('notes')
    user_id = data.get('user_id')
    user_name = data.get('user_name')
    
    if not all([assembly_code, process_name, rollback_reason_id, user_id, user_name]):
        return jsonify({'success': False, 'message': '필수 데이터가 부족합니다'}), 400
    
    conn = get_db()
    cursor = conn.cursor()
    
    try:
        # 공정 날짜 컴럼 매핑
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
            return jsonify({'success': False, 'message': f'잘못된 공정명: {process_name}'}), 400
        
        # 1. 해당 공정이 완료되어 있는지 확인
        cursor.execute(f'SELECT {date_col_name} FROM assembly_items WHERE assembly_code = %s', (assembly_code,))
        current_status = cursor.fetchone()
        
        if not current_status or current_status[date_col_name] is None:
            return jsonify({
                'success': False,
                'message': f'{process_name} 공정이 완료되지 않아 롤백할 수 없습니다'
            }), 400
        
        # 2. 롤백 실행 (NULL로 설정)
        cursor.execute(f'UPDATE assembly_items SET {date_col_name} = NULL WHERE assembly_code = %s', (assembly_code,))
        
        # 3. 롤백 로그 기록
        cursor.execute("""
            INSERT INTO process_logs (
                user_id, user_name, assembly_code, process_name, action, action_date,
                rollback_reason_id, notes
            ) VALUES (%s, %s, %s, %s, 'CANCEL', NOW(), %s, %s)
        """, (user_id, user_name, assembly_code, process_name, rollback_reason_id, notes))
        
        conn.commit()
        
        print(f"[Flask] 롤백 성공: {assembly_code} {process_name} by {user_name}")
        
        return jsonify({
            'success': True,
            'message': f'{assembly_code}의 {process_name} 공정이 성공적으로 롤백되었습니다'
        })
        
    except Exception as e:
        conn.rollback()
        print(f"[Flask] 롤백 오류: {e}")
        return jsonify({
            'success': False,
            'message': f'롤백 중 오류가 발생했습니다: {e}'
        }), 500
    finally:
        conn.close()

# Flask 앱 실행
if __name__ == '__main__':
    print("Flask 애플리케이션 실행 시작")
    app.run(host='0.0.0.0', port=5000, debug=True)

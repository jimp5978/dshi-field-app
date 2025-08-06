"""
조립품 관련 유틸리티 함수들
"""

def calculate_assembly_status(assembly_data):
    """조립품 상태 계산 (Ruby ProcessManager 로직과 동일)"""
    try:
        # 8단계 공정 순서
        processes = [
            ('FIT_UP', assembly_data.get('fit_up_date')),
            ('FINAL', assembly_data.get('final_date')),
            ('ARUP_FINAL', assembly_data.get('arup_final_date')),
            ('GALV', assembly_data.get('galv_date')),
            ('ARUP_GALV', assembly_data.get('arup_galv_date')),
            ('SHOT', assembly_data.get('shot_date')),
            ('PAINT', assembly_data.get('paint_date')),
            ('ARUP_PAINT', assembly_data.get('arup_paint_date'))
        ]
        
        # 완료된 공정들과 불필요한 공정들 구분
        completed_processes = []
        skipped_processes = []
        
        for name, date in processes:
            if date and str(date).strip():
                date_str = str(date)
                if '1900' in date_str:
                    # 1900-01-01은 불필요한 공정 (건너뛰기)
                    skipped_processes.append(name)
                else:
                    # 실제 완료된 공정
                    completed_processes.append((name, date))
        
        # 전체 공정 수 (8개) - 건너뛴 공정 수 = 필요한 공정 수
        total_required_processes = 8 - len(skipped_processes)
        
        # 상태 및 마지막 공정 계산
        if completed_processes:
            # 가장 마지막 완료된 공정
            last_process_name, last_date = completed_processes[-1]
            
            # 실제 완료된 공정 수가 필요한 공정 수와 같으면 완료
            status = '완료' if len(completed_processes) >= total_required_processes else '진행중'
            last_process = last_process_name
        else:
            last_process = '시작전'
            status = '대기'
        
        # 다음 공정 계산
        next_process = None
        for name, date in processes:
            if date and str(date).strip():
                date_str = str(date)
                if '1900' in date_str:
                    # 불필요한 공정은 건너뛰기
                    continue
            else:
                # 날짜가 없거나 비어있는 경우 미완료 공정
                next_process = name
                break
        
        # 다음 공정 한국어 변환
        next_process_korean = {
            'FIT_UP': 'FIT-UP',
            'FINAL': 'FINAL',
            'ARUP_FINAL': 'ARUP FINAL',
            'GALV': 'GALV',
            'ARUP_GALV': 'ARUP GALV',
            'SHOT': 'SHOT',
            'PAINT': 'PAINT',
            'ARUP_PAINT': 'ARUP PAINT'
        }.get(next_process, '완료')
        
        # 계산된 상태 정보를 assembly_data에 추가
        assembly_data['status'] = status
        assembly_data['lastProcess'] = last_process
        assembly_data['nextProcess'] = next_process_korean
        
        return assembly_data
        
    except Exception as e:
        print(f"상태 계산 오류: {e}")
        # 오류 시 기본값 설정
        assembly_data['status'] = '오류'
        assembly_data['lastProcess'] = '알 수 없음'
        assembly_data['nextProcess'] = '알 수 없음'
        return assembly_data
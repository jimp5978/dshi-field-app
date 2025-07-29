#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pandas as pd
import pymysql
import pymysql.cursors
from datetime import datetime
import sys
import traceback

# 데이터베이스 연결 설정
from config_env import get_db_config
DB_CONFIG = get_db_config()

def get_db_connection():
    """MySQL 데이터베이스 연결"""
    try:
        connection = pymysql.connect(**DB_CONFIG)
        return connection
    except Exception as e:
        print(f"데이터베이스 연결 오류: {e}")
        return None

def clean_process_value(value):
    """공정 상태 값 정리"""
    # N/A가 NaN으로 읽혀온 경우 (생략된 공정 - 공정 불필요)
    if pd.isna(value):
        return datetime(1900, 1, 1).date()
    
    # 문자열로 변환
    str_value = str(value).strip()
    
    # 빈 문자열 처리 (완료되지 않은 공정)
    if str_value == '':
        return None
    
    # 날짜 형식 파싱
    try:
        # Excel에서 날짜가 숫자로 올 수 있음
        if str_value.replace('.', '').replace('-', '').isdigit():
            # Excel 날짜 숫자인 경우 pandas로 변환
            excel_date = pd.to_datetime(value, origin='1899-12-30', unit='D')
            return excel_date.date()
        else:
            # 문자열 날짜 파싱 시도
            parsed_date = pd.to_datetime(str_value, errors='coerce')
            if not pd.isna(parsed_date):
                return parsed_date.date()
    except:
        pass
    
    # 파싱할 수 없는 경우 None 반환
    print(f"파싱할 수 없는 값: {value}")
    return None

def import_assembly_data():
    """엑셀 파일에서 ASSEMBLY 데이터 가져와서 MySQL에 입력"""
    try:
        print("=== DSHI ASSEMBLY 데이터 가져오기 ===")
        print("1. 기존 데이터 유지하고 새 데이터 추가")
        print("2. 전체 삭제 후 새 데이터 입력")
        print("3. 마지막 날짜 이후 데이터만 업데이트")
        
        choice = input("선택하세요 (1, 2 또는 3): ").strip()
        
        # 엑셀 파일 읽기
        excel_file = r'E:\DSHI_RPA\APP\assembly_data.xlsx'
        print(f"엑셀 파일 읽는 중: {excel_file}")
        
        # total_arup 시트 읽기 (빈 셀을 NaN으로 처리하지 않고, N/A만 명시적으로 처리)
        try:
            df = pd.read_excel(excel_file, sheet_name='total_arup', keep_default_na=False, na_values=['N/A', 'n/a', 'NA', 'na'])
            print(f"total_arup 시트에서 {len(df)}개 행을 읽었습니다.")
        except Exception as e:
            print(f"total_arup 시트 읽기 실패, 첫 번째 시트 시도: {e}")
            df = pd.read_excel(excel_file, sheet_name=0, keep_default_na=False, na_values=['N/A', 'n/a', 'NA', 'na'])
            print(f"첫 번째 시트에서 {len(df)}개 행을 읽었습니다.")
        
        # 컬럼명 확인
        print("엑셀 컬럼명:")
        for i, col in enumerate(df.columns):
            print(f"  {i}: {col}")
        
        # 데이터베이스 연결
        connection = get_db_connection()
        if not connection:
            print("데이터베이스 연결 실패")
            return False
        
        try:
            with connection.cursor(pymysql.cursors.DictCursor) as cursor:
                if choice == "2":
                    print("기존 데이터 삭제 중...")
                    cursor.execute("DELETE FROM arup_ecs")
                    print("기존 데이터 삭제 완료")
                elif choice == "3":
                    print("마지막 날짜 이후 데이터만 업데이트 진행")
                    # 1. DB에서 마지막 날짜(last_day) 구하기
                    cursor.execute("""
                        SELECT MAX(GREATEST(
                            IFNULL(fit_up_date, '1900-01-01'),
                            IFNULL(final_date, '1900-01-01'),
                            IFNULL(arup_final_date, '1900-01-01'),
                            IFNULL(galv_date, '1900-01-01'),
                            IFNULL(arup_galv_date, '1900-01-01'),
                            IFNULL(shot_date, '1900-01-01'),
                            IFNULL(paint_date, '1900-01-01'),
                            IFNULL(arup_paint_date, '1900-01-01')
                        )) AS last_day FROM arup_ecs
                    """)
                    last_day_row = cursor.fetchone()
                    last_day = last_day_row['last_day'] if last_day_row and last_day_row['last_day'] else datetime(1900, 1, 1).date()
                    print(f"DB의 마지막 날짜: {last_day}")

                else:
                    print("기존 데이터 유지하며 진행")
                
                inserted_count = 0
                skipped_count = 0
                
                for index, row in df.iterrows():
                    try:
                        assembly_code = str(row.iloc[0]).strip() if not pd.isna(row.iloc[0]) else ''
                        company = str(row.iloc[1]).strip() if not pd.isna(row.iloc[1]) else ''
                        zone = str(row.iloc[2]).strip() if not pd.isna(row.iloc[2]) else ''
                        item = str(row.iloc[3]).strip() if not pd.isna(row.iloc[3]) else ''
                        weight_net = float(row.iloc[4]) if not pd.isna(row.iloc[4]) else None
                        remark = str(row.iloc[13]).strip() if not pd.isna(row.iloc[13]) else ''

                        if assembly_code == '' or assembly_code == 'nan':
                            skipped_count += 1
                            continue

                        fit_up_date = clean_process_value(row.iloc[5] if len(row) > 5 else None)
                        final_date = clean_process_value(row.iloc[6] if len(row) > 6 else None)
                        arup_final_date = clean_process_value(row.iloc[7] if len(row) > 7 else None)
                        galv_date = clean_process_value(row.iloc[8] if len(row) > 8 else None)
                        arup_galv_date = clean_process_value(row.iloc[9] if len(row) > 9 else None)
                        shot_date = clean_process_value(row.iloc[10] if len(row) > 10 else None)
                        paint_date = clean_process_value(row.iloc[11] if len(row) > 11 else None)
                        arup_paint_date = clean_process_value(row.iloc[12] if len(row) > 12 else None)

                        # 3번: last_day와 같거나 이후의 날짜가 하나라도 있으면 UPDATE
                        if choice == "3":
                            date_list = [
                                fit_up_date, final_date, arup_final_date,
                                galv_date, arup_galv_date, shot_date,
                                paint_date, arup_paint_date
                            ]
                            # 날짜가 last_day와 같거나 이후인 경우만 업데이트
                            if not any(d and d >= last_day for d in date_list):
                                skipped_count += 1
                                continue

                            # UPDATE (존재하면 갱신, 없으면 INSERT)
                            sql_update = """
                            INSERT INTO arup_ecs (
                                assembly_code, company, zone, item, weight_net,
                                fit_up_date, final_date, arup_final_date,
                                galv_date, arup_galv_date, shot_date,
                                paint_date, arup_paint_date, remark, updated_at
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            ON DUPLICATE KEY UPDATE
                                company=VALUES(company),
                                zone=VALUES(zone),
                                item=VALUES(item),
                                weight_net=VALUES(weight_net),
                                fit_up_date=VALUES(fit_up_date),
                                final_date=VALUES(final_date),
                                arup_final_date=VALUES(arup_final_date),
                                galv_date=VALUES(galv_date),
                                arup_galv_date=VALUES(arup_galv_date),
                                shot_date=VALUES(shot_date),
                                paint_date=VALUES(paint_date),
                                arup_paint_date=VALUES(arup_paint_date),
                                remark=VALUES(remark),
                                updated_at=VALUES(updated_at)
                            """
                            current_time = datetime.now()
                            cursor.execute(sql_update, (
                                assembly_code, company, zone, item, weight_net,
                                fit_up_date, final_date, arup_final_date,
                                galv_date, arup_galv_date, shot_date,
                                paint_date, arup_paint_date, remark, current_time
                            ))
                            inserted_count += 1
                        else:
                            # 기존 방식 (INSERT)
                            sql = """
                            INSERT INTO arup_ecs (
                                assembly_code, company, zone, item, weight_net,
                                fit_up_date, final_date, arup_final_date,
                                galv_date, arup_galv_date, shot_date,
                                paint_date, arup_paint_date, remark, updated_at
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                            """
                            current_time = datetime.now()
                            cursor.execute(sql, (
                                assembly_code, company, zone, item, weight_net,
                                fit_up_date, final_date, arup_final_date,
                                galv_date, arup_galv_date, shot_date,
                                paint_date, arup_paint_date, remark, current_time
                            ))
                            inserted_count += 1

                        if inserted_count % 100 == 0:
                            print(f"  {inserted_count}개 입력/업데이트 완료...")

                    except Exception as e:
                        print(f"행 {index + 1} 처리 중 오류: {e}")
                        skipped_count += 1
                        continue

                connection.commit()
                print(f"=== 데이터 입력/업데이트 완료 ===")
                print(f"입력/업데이트된 데이터: {inserted_count}개")
                print(f"건너뛴 데이터: {skipped_count}개")
                
                # 결과 확인
                cursor.execute("SELECT COUNT(*) as total FROM arup_ecs")
                total_count = cursor.fetchone()['total']
                print(f"데이터베이스 총 데이터: {total_count}개")
                
                # 샘플 데이터 출력
                print("\n=== 샘플 데이터 ===")
                cursor.execute("SELECT * FROM arup_ecs LIMIT 5")
                samples = cursor.fetchall()
                for sample in samples:
                    print(f"  {sample['company']} | {sample['zone']} | {sample['item']} | {sample['assembly_code']}: "
                          f"Fit-up={sample['fit_up_date']}, "
                          f"Final={sample['final_date']}, "
                          f"ARUP_Paint={sample['arup_paint_date']}, "
                          f"Remark={sample['remark']}")
                
                return True
                
        finally:
            connection.close()
            
    except Exception as e:
        print(f"데이터 가져오기 오류: {e}")
        traceback.print_exc()
        return False

# def create_sample_data():
#     """샘플 데이터 생성 (엑셀 파일이 없는 경우)"""
#     try:
#         print("=== 샘플 데이터 생성 ===")
        
#         connection = get_db_connection()
#         if not connection:
#             return False
        
#         try:
#             with connection.cursor(pymysql.cursors.DictCursor) as cursor:
#                 # 기존 데이터 삭제
#                 cursor.execute("DELETE FROM assembly_items")
                
#                 # 샘플 데이터
#                 sample_assemblies = [
#                     'A001-001', 'A001-002', 'A001-003', 'A001-004', 'A001-005',
#                     'B001-001', 'B001-002', 'B001-003', 'B001-004', 'B001-005',
#                     'C001-001', 'C001-002', 'C001-003', 'C001-004', 'C001-005'
#                 ]
                
#                 current_time = datetime.now()
                
#                 for i, assembly_code in enumerate(sample_assemblies):
#                     # 각 ASSEMBLY마다 다른 진행 상황 생성
#                     progress = i % 8  # 0-7 단계
                    
#                     fit_up = current_time if progress >= 1 else None
#                     nde = current_time if progress >= 2 else None
#                     vidi = current_time if progress >= 3 else None
#                     galv = current_time if progress >= 4 else None
#                     shot = current_time if progress >= 5 else None
#                     paint = current_time if progress >= 6 else None
#                     packing = current_time if progress >= 7 else None
                    
#                     sql = """
#                     INSERT INTO assembly_items (
#                         zone,
#                         item,
#                         assembly_code, 
#                         fit_up_date, 
#                         nde_date, 
#                         vidi_date, 
#                         galv_date, 
#                         shot_date, 
#                         paint_date, 
#                         packing_date,
#                         updated_at
#                     ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
#                     """
                    
#                     cursor.execute(sql, (
#                         'TEST_ZONE', 'TEST_ITEM', assembly_code, fit_up, nde, vidi, galv, shot, paint, packing,
#                         current_time
#                     ))
                
#                 connection.commit()
#                 print(f"{len(sample_assemblies)}개의 샘플 데이터 생성 완료")
#                 return True
                
#         finally:
#             connection.close()
            
#     except Exception as e:
#         print(f"샘플 데이터 생성 오류: {e}")
#         return False

if __name__ == '__main__':
    # print("DSHI ASSEMBLY 데이터 가져오기 스크립트")
    # print("1. 엑셀 파일에서 가져오기")
    # print("2. 샘플 데이터 생성")
    
    # if len(sys.argv) > 1 and sys.argv[1] == 'sample':
    #     success = create_sample_data()
    # else:
    success = import_assembly_data()
    
    if success:
        print("✅ 작업 완료")
    else:
        print("❌ 작업 실패")
        sys.exit(1)
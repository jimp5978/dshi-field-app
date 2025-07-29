import pandas as pd
import mysql.connector
from mysql.connector import Error
import os

# MySQL 연결 설정
DB_CONFIG = {
    'host': 'localhost',
    'database': 'dshi_field_pad',
    'user': 'root',
    'password': ''
}

def import_excel_to_database(excel_file_path):
    """Excel 파일의 데이터를 MySQL 데이터베이스로 가져오기"""
    try:
        # Excel 파일 읽기
        if not os.path.exists(excel_file_path):
            print(f"Excel 파일을 찾을 수 없습니다: {excel_file_path}")
            return False
        
        df = pd.read_excel(excel_file_path)
        print(f"Excel 파일에서 {len(df)}개 행을 읽었습니다.")
        print("컬럼:", df.columns.tolist())
        
        # MySQL 연결
        connection = mysql.connector.connect(**DB_CONFIG)
        cursor = connection.cursor()
        
        imported_count = 0
        
        # 각 행을 데이터베이스에 삽입
        for index, row in df.iterrows():
            try:
                # 컬럼명에 따라 데이터 매핑 (Excel 컬럼명에 맞게 수정 필요)
                assembly_name = str(row.get('조립품명', row.get('Assembly_Name', '')))
                drawing_number = str(row.get('도면번호', row.get('Drawing_Number', '')))
                revision = str(row.get('리비전', row.get('Revision', 'A')))
                
                # 빈 값 체크
                if assembly_name and assembly_name != 'nan' and drawing_number and drawing_number != 'nan':
                    cursor.execute("""
                        INSERT INTO assemblies (assembly_name, drawing_number, revision)
                        VALUES (%s, %s, %s)
                        ON DUPLICATE KEY UPDATE
                        assembly_name = VALUES(assembly_name),
                        revision = VALUES(revision)
                    """, (assembly_name, drawing_number, revision))
                    
                    imported_count += 1
                    
            except Exception as e:
                print(f"행 {index + 1} 처리 중 오류: {e}")
                continue
        
        connection.commit()
        cursor.close()
        connection.close()
        
        print(f"총 {imported_count}개의 조립품 데이터를 가져왔습니다.")
        return True
        
    except Exception as e:
        print(f"Excel 가져오기 오류: {e}")
        return False

def show_excel_preview(excel_file_path, rows=5):
    """Excel 파일 미리보기"""
    try:
        if not os.path.exists(excel_file_path):
            print(f"Excel 파일을 찾을 수 없습니다: {excel_file_path}")
            return
        
        df = pd.read_excel(excel_file_path)
        print(f"\n=== Excel 파일 미리보기 (처음 {rows}행) ===")
        print(f"전체 행 수: {len(df)}")
        print(f"컬럼: {df.columns.tolist()}")
        print("\n데이터:")
        print(df.head(rows))
        
    except Exception as e:
        print(f"Excel 미리보기 오류: {e}")

if __name__ == '__main__':
    excel_file = 'assembly_data.xlsx'
    
    print("DSHI Field Pad Excel 데이터 가져오기")
    print(f"Excel 파일: {excel_file}")
    
    # Excel 파일 미리보기
    show_excel_preview(excel_file)
    
    # 가져오기 실행 여부 확인
    proceed = input("\nExcel 데이터를 데이터베이스로 가져오시겠습니까? (y/n): ")
    
    if proceed.lower() == 'y':
        if import_excel_to_database(excel_file):
            print("Excel 데이터 가져오기가 완료되었습니다.")
        else:
            print("Excel 데이터 가져오기에 실패했습니다.")
    else:
        print("작업이 취소되었습니다.")
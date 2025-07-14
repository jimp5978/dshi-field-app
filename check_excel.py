import pandas as pd

# 엑셀 파일의 시트 이름 확인
file_path = 'E:/DSHI_RPA/APP/assembly_data.xlsx'
excel_file = pd.ExcelFile(file_path)
print("시트 목록:", excel_file.sheet_names)

# 첫 번째 시트 읽기
df = pd.read_excel(file_path, sheet_name=0)  # 첫 번째 시트 읽기

print(f"\n행 수: {len(df)}")
print(f"\n컬럼 목록: {df.columns.tolist()}")
print(f"\n처음 10행:")
print(df.head(10))

# N/A 값 확인
print("\n\nN/A 값 확인:")
for col in df.columns:
    if df[col].dtype == 'object':  # 문자열 컬럼만 확인
        na_values = df[col].astype(str).str.upper().str.strip()
        na_count = na_values.isin(['N/A', 'NA', 'N.A']).sum()
        if na_count > 0:
            print(f"{col} 컬럼: N/A 값 {na_count}개")

# DSHI Field Pad Application

동성중공업 현장 ASSEMBLY 관리 시스템

## 구성요소
- **Flutter App**: Android 현장 관리 앱
- **Flask Server**: REST API 서버
- **MySQL Database**: ASSEMBLY 데이터 저장

## 환경 설정

### 회사에서 작업
```bash
# 환경변수 설정 안함 (기본값)
python flask_server.py
python import_data.py
```

### 집에서 작업
```bash
# 환경변수 설정
set WORK_ENV=home

# config_env.py에서 회사 IP 설정 필요
python flask_server.py
```

## 데이터베이스 구조
- **assembly_items**: 조립품 공정 관리
  - zone, item, assembly_code
  - 각 공정별 날짜 (fit_up_date, nde_date, vidi_date, galv_date, shot_date, paint_date, packing_date)
  - N/A: 1900-01-01 (생략된 공정)
  - NULL: 완료되지 않은 공정

## 사용법
1. MySQL 테이블 생성
2. import_data.py로 엑셀 데이터 가져오기
3. flask_server.py 실행
4. Flutter 앱 실행

## 파일 구조
- `flask_server.py`: REST API 서버
- `import_data.py`: 엑셀 데이터 가져오기
- `config_env.py`: 환경별 설정
- `dshi_field_app/`: Flutter 앱
- `assembly_data.xlsx`: 원본 데이터
# DSHI Field Pad App 개발 문서

## 프로젝트 개요
- 목적: 현장 작업자를 위한 모바일 ASSEMBLY 관리 시스템
- 회사: 동성중공업(DSHI) - 용접 관련 제품 제조
- 개발 시작: 2025-07-09 (재시작)

## 기술 스택
- Frontend: Flutter (모바일 앱)
- Backend: Flask (Python API 서버)
- Database: MySQL
- 플랫폼: Android (주), Windows (개발용)

## 핵심 요구사항

### 1. 공정 관리 시스템
- **7단계 공정**: Fit-up → NDE → VIDI → GALV → SHOT → PAINT → PACKING
- **순차 진행**: 이전 공정 완료 후 다음 공정 진행 가능
- **배치 처리**: 여러 ASSEMBLY 동시 처리
- **공정 생략 처리 규칙**: 공정이 불필요한 경우 해당 셀에 "N/A"로 입력됨.
 "N/A"는 대소문자 구분 없이 인식되며("n/a", "N/A" 등), 해당 공정은 자동으로 생략됨.
  셀이 비어 있는 경우는 생략으로 간주하지 않으며, 미진행 상태로 처리됨. (추후 구현)


### 2. 권한 시스템 (재정의 - 2025-07-10)
- **Level 1**: 외부업체
  - ASSEMBLY 검색
  - LIST UP
  - 검사신청
  - 자기가 신청한 날짜별 검사신청 확인 (추후 구현)
- **Level 2**: 추후 사용 예정 (현재 미사용)
- **Level 3**: DSHI 현장직원
  - Level 1의 모든 기능
  - 롤백 기능
  - PDF 도면 보기 (추후 구현)
  - 기본 데이터(ASSEMBLY 정보) 엑셀 업로드 (추후 구현)
  - 날짜별 전체 검사신청 확인 (추후 구현)
- **Level 4-5**: DSHI 관리직원
  - 대시보드 데이터 확인용 관리자 기능 (추후 구현)
- **Admin**: 모든 기능 사용 및 수정관리

### 2-1. 테스트 계정 정보 (재정의 - 2025-07-10)
**레벨별 테스트 계정 (아이디/비밀번호 동일)**
- **Admin**: a / a
- **Level 1** (외부업체): l1 / l1
- **Level 2** (미사용): l2 / l2
- **Level 3** (DSHI 현장직원): l3 / l3
- **Level 4** (DSHI 관리직원): l4 / l4
- **Level 5** (DSHI 시스템관리자): l5 / l5

**데이터베이스 테이블 구조:**
- users: 기본 사용자 정보 + permission_level
- dshi_staff: DSHI 직원 정보 (Level 3-5, department 필드)
- external_users: 외부업체 정보 (Level 1-2, company_name 필드)

**테스트 계정 생성 방법:**
```bash
python backup_deleted/create_test_users.py
```

### 3. 주요 기능
- **검색**: ASSEMBLY 코드로 검색
- **공정 업데이트**: 공정 완료 처리
- **롤백**: 완료된 공정 되돌리기 (Level 3+)
- **PDF 도면**: 로컬 파일 보기 (Level 3+)
- **검사신청**: 외부업체 검사 요청
- **엑셀 업로드**: ASSEMBLY 데이터 업로드 (Level 3+, 추후 구현)
- **검사신청 확인**: 날짜별 검사신청 확인 (추후 구현)

## 개발 단계

### Phase 1: 기본 시스템 (우선순위 높음)
1. **환경 설정**
   - Flutter 프로젝트 생성
   - MySQL 데이터베이스 설정
   - Flask API 서버 기본 구조

2. **핵심 기능**
   - 로그인 시스템
   - ASSEMBLY 검색
   - 공정 상태 표시
   - 기본 공정 업데이트

### Phase 2: 고급 기능 (우선순위 중간)
1. **권한 시스템**
   - 레벨별 접근 제어
   - UI 동적 변경

2. **롤백 시스템**
   - 공정 되돌리기
   - 롤백 로그 기록

3. **PDF 연동**
   - 로컬 PDF 파일 보기
   - 도면 관리

### Phase 3: 부가 기능 (우선순위 낮음)
1. **검사신청 시스템**
2. **리포트 기능**
3. **알림 시스템**

## 데이터 정보
- **ASSEMBLY 데이터**: 약 373개 (기존 데이터 존재)
- **데이터베이스**: field_app_db
- **테이블**: assembly_items, users, process_logs 등

## 필수 파일 정의

### 데이터베이스 관련
- assembly_data.xlsx (81.46KB): 기본 ASSEMBLY 데이터, process/bom/arup 시트 포함 (2025-07-10 업데이트)
- import_data.py (5.12KB): 엑셀 데이터를 MySQL DB로 입력하는 스크립트
- setup_database.py (4.96KB): MySQL 테이블 생성 및 초기 설정
- config.py (883B): DB 연결 설정 (field_app_user/F!eldApp_Pa$w0rd_2025#)
- backup_deleted/create_test_users.py: 레벨별 테스트 계정 생성 스크립트

### 백엔드 서버
- flask_server.py: MySQL 연동 Flask API 서버 (포트 5001)
  - API: 로그인, 검색, 공정 업데이트, 롤백 사유
  - 373개 ASSEMBLY 데이터와 연결
  - 7단계 공정 관리 (Fit-up -> NDE -> VIDI -> GALV -> SHOT -> PAINT -> PACKING)

### 프론트엔드 앱
- dshi_field_app/: 새로 생성된 Flutter 프로젝트
  - pubspec.yaml: 필수 패키지 (http, shared_preferences, crypto, intl)
  - lib/main.dart: 기본 Flutter 템플릿 (향후 DSHI 앱으로 변경 예정)
  - 빌드 테스트 완료, 문제 없음

### 문서
- docs/development.md: 통합 개발 문서 (프로젝트 정보 + 작업 로그)
- docs/work_rules.md: Claude와 나와 대화 및 작업 지침 및 협업 규칙

### 에셋
- image/: 회사 이미지 폴더 (동성중공업 로고 및 패턴 이미지)

### 백업
- backup_deleted/: 정리된 기존 파일들 백업 (21개 파일/폴더)
- field_pad_app/: 손상된 기존 Flutter 프로젝트 (사용 안 함)

## 개발 환경
- **주 개발 플랫폼**: Android 에뮬레이터
- **테스트 환경**: Windows (개발용)
- **배포 대상**: Android 태블릿/스마트폰

---

# 개발 로그

## 2025-07-09

### 현재 상황 점검
- 기존 구현 내용 검토 완료
- 문서 재정비 및 통합 완료
- 새로운 개발 방향 설정

### 오늘 작업 계획
1. ✅ 문서 통합 및 재작성
2. ✅ 현재 환경 상태 확인
3. ✅ 기존 코드 상태 점검
4. ✅ 데이터베이스 상태 확인
5. ✅ Flutter 앱 DSHI 기본 구조 완성
6. ✅ UI 레이아웃 최적화 및 완성

### 작업 내용
- ✅ implementation_log.md + project_plan.md → development.md 통합
- ✅ work_rules.md 생성 (작업 지침)
- ✅ 불필요한 파일들 정리 완료 (21개 파일/폴더 이동)
- ✅ lib 폴더 정리 완료 (120KB → 5KB 절약)
- ✅ **새 Flutter 프로젝트 생성**: dshi_field_app
  - Flutter 3.32.5 환경 정상 작동 확인
  - 필수 패키지 설치 완료 (http, shared_preferences, crypto, intl)
  - 빌드 테스트 ✅ 문제 없음
- ✅ **Flask 서버 복구**: flask_server.py
  - MySQL 데이터베이스 연동 서버
  - API 엔드포인트: 로그인, 검색, 공정 업데이트
  - 포트 5001에서 실행
- ✅ **DSHI 앱 기본 구조 완성**:
  - ASSEMBLY 검색 화면을 메인 시작 화면으로 설정
  - 숫자 키패드 (0-9, DEL, 백스페이스) 구현
  - 검색 결과 리스트 (체크박스 포함)
  - LIST UP 기능 (선택 항목 저장 및 화면에서 제거)
  - LIST 버튼 (저장된 항목 확인, 개별/전체 삭제)
  - 완전한 UI 레이아웃 구현
- ✅ **UI 레이아웃 최적화 완성**:
  - NDK 버전 호환성 문제 해결 (27.0.12077973)
  - 키패드 크기 조정으로 화면 겹침 문제 해결
  - LIST UP과 검색 버튼을 같은 라인에 배치
  - 왼쪽: 검색결과 + LIST UP, 오른쪽: 키패드 + 검색
  - 키패드 박스화로 영역 분리 및 최적화
- ✅ **UI 디자인 완전 최적화**:
  - 검색 결과창 크기 조정 (height: 500px)
  - 입력창 폰트 크기 증가 (fontSize: 24)
  - 키패드 숫자 크기 대폭 증가 (fontSize: 28)
  - LIST 버튼 크기 확대 및 디자인 개선
  - 테두리 제거로 깔끔한 UI 구현
  - 입력창과 키패드 사이 적절한 여백 (16px)
- ✅ **LIST 화면 완전 구현**:
  - 팝업에서 새 페이지로 분리
  - 상단 3개 버튼: 전체선택, 선택삭제, 전체삭제
  - 하단 2개 신규 버튼: 날짜선택, 검사신청
  - 체크박스 다중 선택 시스템
  - 전체선택/해제 토글 기능

### 현재 완성된 기능
1. **ASSEMBLY 검색 화면** (완전 구현):
   - 큰 숫자 키패드로 ASSEMBLY 코드 입력 (fontSize: 28)
   - 실시간 입력 표시 (fontSize: 24, DEL: 전체삭제, 백스페이스: 한글자삭제)
   - 검색 버튼으로 결과 조회
   - 깔끔한 UI (테두리 제거, 적절한 여백)

2. **검색 결과 관리** (완전 구현):
   - 체크박스가 있는 리스트 형태 (height: 500px)
   - ASSEMBLY NO, 최종공정, 완료일자 표시
   - 다중 선택 가능
   - 선택된 항목 LIST UP 기능

3. **LIST UP 시스템** (완전 구현):
   - 선택된 항목들을 별도 리스트에 저장
   - 저장된 항목은 검색 결과에서 자동 제거
   - LIST 버튼으로 저장된 항목 확인 (크기 확대)
   - 새 페이지로 분리된 LIST 화면

4. **LIST 화면** (완전 구현):
   - 상단 3개 버튼: 전체선택/해제, 선택삭제(n개), 전체삭제
   - 체크박스 다중 선택 시스템
   - 하단 2개 신규 버튼: 날짜선택, 검사신청
   - 개별/전체 삭제 기능

5. **UI 레이아웃** (완전 최적화):
   - 왼쪽: 검색 결과 (500px 고정)
   - 오른쪽: 입력창 + 키패드 (여백 16px)
   - 하단: LIST UP + 검색 버튼 (가로 배치)
   - 상단: LIST 버튼 (저장된 항목 수 표시)

### 다음 작업 예정 (우선순위)
1. **실제 ASSEMBLY 데이터 연동**
   - Flask 서버 검색 API 연동
   - 373개 ASSEMBLY 데이터 검색 기능
   - 7단계 공정 상태 표시 및 관리
   - 공정 업데이트 API 연동

2. **부가 기능 구현**
   - 롤백 기능 (Level 3+ 전용)
   - PDF 도면 연동
   - 검사신청 API 연동 (날짜별 구분)
   - 리포트 기능
   - UI 브랜딩 (회사 로고, 배경 패턴)
   - 알림 시스템

### 2025-07-09 오후 추가 작업
6. **검사신청 기능 개선** (완전 구현):
   - 검색 후 입력창 자동 삭제 기능
   - 날짜 변경시 메시지 제거 (조용히 변경)
   - 검사신청 에러 메시지 개선:
     * 공정별 그룹화 로직 구현
     * 가장 많은 공정을 "정상"으로 판단
     * 소수 공정의 ASSEMBLY NO만 에러 표시
     * 스낵바에서 경고 팝업창으로 변경
   - 검사 신청 완료 후 해당 항목 LIST에서 자동 제거
   - 날짜별 검사 신청 데이터 구분 (향후 API 연동시 구현 예정)

7. **로그인 시스템 구현** (완전 구현):
   - 로그인 화면 UI 구현 (login_screen.dart)
   - SHA256 패스워드 해싱 처리
   - Flask 서버 API 연동 (POST /api/login)
   - 네트워크 연결 문제 해결 (localhost → 실제 IP 주소 사용)
   - 서버 연결 테스트 기능 추가
   - 테스트 계정으로 로그인 성공 확인
   - 사용자 정보 및 권한 레벨 표시

8. **권한 레벨별 화면 분기 구현** (진행 중):
   - AssemblySearchScreen을 별도 파일로 분리 (assembly_search_screen.dart)
   - 로그인 성공 후 메인 화면으로 이동 기능
   - 권한 레벨별 화면 분기 함수 구현 (향후 확장 가능)
   - AppBar에 사용자 정보 및 권한 레벨 표시
   - 로그아웃 기능 추가

9. **권한 레벨별 기능 제한 구현** (코드 작성 완료):
   - Level 1-2 (외부업체): 검사신청 전용 화면 구현
     * 오렌지색 AppBar로 구분
     * ASSEMBLY 검색 기능 제거
     * 검사신청 버튼만 표시
     * 권한 설명 표시
   - Level 3-5 (DSHI 직원): 전체 기능 사용 가능
     * 파란색 AppBar
     * ASSEMBLY 검색, LIST UP, 검사신청 모든 기능 사용
   - 테스트 계정 안내 업데이트 (Level 2 추가)

### 현재 완성도
- **UI/UX**: 100% 완성
- **기본 기능**: 100% 완성 (검색, LIST UP, 검사신청)
- **로그인 시스템**: 100% 완성 (Flask API 연동, 테스트 계정 로그인 성공)
- **권한 레벨별 화면 분기**: 100% 완성 (Level 1 수정 완료, 테스트 완료)
- **데이터 연동**: 미구현 (임시 데이터 사용 중)
- **PDF 연동**: 미구현
- **롤백 기능**: 미구현

### UI/UX 완성도
- ✅ **메인 화면**: 100% 완성 (디자인, 기능, 레이아웃)
- ✅ **LIST 화면**: 100% 완성 (다중선택, 버튼배치, 기능)
- ✅ **전체 UI**: 사용자 친화적, 태블릿 최적화 완료
- ✅ **코드 구조**: 재사용 가능, 확장 가능한 구조

### 핵심 파일들
- `dshi_field_app/`: 완성된 Flutter 프로젝트
- `flask_server.py`: MySQL 연동 API 서버 (포트 5001)
- `assembly_data.xlsx`: 373개 ASSEMBLY 데이터
- `import_data.py`: 엑셀 데이터를 MySQL DB로 입력하는 스크립트
- `setup_database.py`: MySQL 테이블 생성 및 초기 설정
- `config.py`: DB 연결 설정 (field_app_user/F!eldApp_Pa$w0rd_2025#)

## 2025-07-10

### 권한 시스템 재정의
- 기존 Level 1-2를 Level 1로 통합
- Level 1에 ASSEMBLY 검색, LIST UP 기능 추가
- Level 2는 추후 사용을 위해 예약
- Level 3에 롤백, PDF 도면, 엑셀 업로드 기능 명시
- Level 4-5는 관리자용 기능으로 추후 구현 예정
- Admin은 모든 기능 사용 가능

### 테스트 계정 재정의
- 기존 긴 아이디(test_level1 등)를 간단하게 변경
- 아이디와 비밀번호 통일 (a/a, l1/l1 등)
- 로그인 화면 테스트 계정 안내 업데이트
- 데이터베이스에 새 테스트 계정 생성 완료 ✅
  - 새 계정 6개 성공적으로 생성
  - 기존 계정도 호환성을 위해 유지

### Level 1 화면 수정 완료 ✅
- 기존 검사신청만 가능한 제한 제거
- Level 1도 전체 기능 사용 가능 (ASSEMBLY 검색, LIST UP, 검사신청)
- _buildExternalUserScreen 메서드 제거
- 모든 레벨이 동일한 화면 사용
- 권한 레벨 표시는 유지 (향후 차별화를 위해)
- 파일 작성 오류 수정 완료
- 테스트 완료: 정상 작동 확인

### 현재 개발 완성도 정리
- **UI/UX**: 100% 완성 ✅
- **기본 기능**: 100% 완성 ✅ (검색, LIST UP, 검사신청)
- **로그인 시스템**: 100% 완성 ✅ (Flask API 연동, 테스트 계정 로그인 성공)
- **권한 레벨별 화면 분기**: 100% 완성 ✅ (Level 1 수정 완료, 테스트 완료)
- **데이터 연동**: 0% (임시 데이터 사용 중)
- **PDF 연동**: 0% (미구현)
- **롤백 기능**: 0% (미구현)
- **검사신청 확인**: 0% (미구현)
- **엑셀 업로드**: 0% (미구현)

### ASSEMBLY 데이터 업데이트 준비
- 새로운 assembly_data.xlsx 파일 확인 (2025-07-10 수정)
  - 시트 구조: 'process', 'bom', 'arup' (3개 시트)
  - 기존 'TN1' 시트가 'process'로 변경됨
  - 373개 데이터 유지
  - N/A 값은 없고 빈 날짜는 NaT로 표시
- import_data.py 수정
  - 시트 이름 'TN1' → 'process'로 변경 ✅
  - N/A 처리 로직 코드 준비 (필요시 추가 가능)
- 데이터베이스 업데이트 계획
  - 'arup' 시트 사용 예정
  - 기존 데이터 삭제 후 새 데이터 입력 필요

### 공정 생략 처리 규칙 N/A 처리 코드
```python
# N/A 처리가 추가된 코드:
if pd.isna(value):
    row_data.append(None)
elif isinstance(value, str) and value.strip().upper() in ['N/A', 'NA', 'N.A', 'N/A']:
    # N/A 값을 NULL로 처리하려면:
    row_data.append(None)
    # 또는 N/A를 특정 날짜(예: 9999-12-31)로 처리하려면:
    # row_data.append(datetime.date(9999, 12, 31))
    # 또는 N/A를 문자열 그대로 저장하려면 (날짜 컬럼이 VARCHAR인 경우):
    # row_data.append('N/A')
elif isinstance(value, pd.Timestamp):
    row_data.append(value.date())
else:
    row_data.append(value)
```

### 다음 작업 계획 (우선순위)
1. **실제 ASSEMBLY 데이터 연동**
   - Flask 서버 검색 API 연동  
   - 373개 ASSEMBLY 데이터 검색 기능
   - 7단계 공정 상태 표시 및 관리
   - 공정 업데이트 API 연동

2. **Level 3 추가 기능**
   - 롤백 버튼 및 기능 구현
   - PDF 보기 버튼 및 기능 구현

3. **검사신청 확인 기능**
   - Level 1: 자기가 신청한 날짜별 확인
   - Level 3+: 전체 검사신청 확인

---

*프로젝트 재시작: 2025-07-09*
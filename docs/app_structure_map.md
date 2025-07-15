# DSHI Field Pad 앱 상세 파일 구조 맵

> 📅 **업데이트**: 2025-07-15  
> 🎯 **상태**: 검사신청 API 연동 완료 - 실시간 데이터 처리 및 레벨별 권한 구현

## 🗂️ 전체 파일 구조

### 📱 **Flutter 앱 (Frontend)**

#### 📄 **main.dart** ⭐ (앱의 핵심 - 1100+ 줄)
```
main.dart
├── 🏗️ DSHIFieldApp (앱 전체 설정)
│   ├── MaterialApp 설정 (한국어 로케일, 테마)
│   └── 시작점: LoginScreen()
│
├── 🔍 AssemblySearchScreen (메인 검색 화면)
│   ├── _onNumberPressed() → 숫자 키패드 입력 처리
│   ├── _onBackspacePressed() → 한 글자 삭제
│   ├── _onDeletePressed() → 전체 삭제 (DEL)
│   ├── _onSearchPressed() → HTTP GET /api/assemblies 호출
│   ├── _onListUpPressed() → 선택 항목들을 저장 리스트로 이동
│   ├── _showInspectionRequests() → 검사신청 확인 화면 이동
│   └── UI 위젯들:
│       ├── 큰 숫자 키패드 (0-9, DEL, ←)
│       ├── 검색 결과 리스트 (체크박스)
│       └── 하단 버튼들 (LIST UP, 검색, 검사신청확인)
│
├── 📋 SavedListScreen (저장된 리스트 화면)
│   ├── _toggleSelectAll() → 전체선택/해제
│   ├── _deleteSelectedItems() → 선택항목 삭제
│   ├── _deleteAllItems() → 전체 삭제
│   ├── _selectDate() → 날짜 선택 달력
│   ├── _requestInspection() → 검사신청 유효성 검사
│   ├── _submitInspectionRequest() → HTTP POST /api/inspection-requests
│   ├── _getNextProcess() → 다음 공정 계산 (Fit-up→NDE→VIDI...)
│   └── _formatDate() → 날짜 YYYY-MM-DD 포맷
│
└── 📊 InspectionRequestScreen (검사신청 확인 화면)
    ├── _loadInspectionRequests() → HTTP GET /api/inspection-requests
    ├── _selectDate() → 조회 날짜 변경
    ├── _showMessage() → 스낵바 메시지 표시
    ├── _formatDate() → 날짜 포맷팅
    └── 레벨별 데이터 필터링 (Level 1: 본인만, Level 3+: 전체)
```

#### 📄 **login_screen.dart** ⭐ (로그인 전용 - 350+ 줄)
```
login_screen.dart
├── 🔐 LoginScreen
│   ├── _handleLogin() → 로그인 메인 로직
│   │   ├── _hashPassword() → SHA256 패스워드 해싱
│   │   ├── _callLoginAPI() → HTTP POST /api/login
│   │   └── SharedPreferences에 JWT 토큰 저장
│   ├── _testServerConnection() → 서버 연결 테스트
│   ├── _navigateToMainScreen() → 로그인 성공 후 화면 이동
│   └── UI 구성:
│       ├── 아이디/비밀번호 입력폼
│       ├── 로그인 버튼
│       ├── 서버 연결 테스트 버튼
│       └── 테스트 계정 안내 (a/a, l1/l1, l3/l3, l5/l5)
```

#### 📄 **pubspec.yaml** (패키지 의존성)
```
dependencies:
├── http: ^1.1.0 (API 통신)
├── shared_preferences: ^2.2.2 (토큰 저장)
├── crypto: ^3.0.3 (SHA256 해싱)
├── flutter_localizations (한국어 지원)
└── intl: ^0.19.0 (날짜 포맷팅)
```

#### 📄 **AndroidManifest.xml** (권한 설정)
```
android/app/src/main/AndroidManifest.xml
└── <uses-permission android:name="android.permission.INTERNET" />
```

---

### 🔧 **Backend 서버**

#### 📄 **flask_server.py** ⭐ (API 서버 - 380+ 줄)
```
flask_server.py
├── 🔧 서버 설정
│   ├── Flask + CORS 설정
│   ├── JWT SECRET_KEY 설정
│   └── config_env.py에서 DB/서버 설정 로드
│
├── 🔐 인증 시스템
│   ├── token_required() → JWT 토큰 검증 데코레이터
│   └── 하드코딩된 테스트 사용자 (a, l1, l3, l5)
│
├── 🌐 API 엔드포인트
│   ├── POST /api/login
│   │   ├── SHA256 패스워드 검증
│   │   ├── JWT 토큰 생성 (24시간 유효)
│   │   └── 사용자 정보 반환 (id, username, full_name, permission_level)
│   │
│   ├── GET /api/assemblies?search=XXX
│   │   ├── MySQL assembly_items 테이블 조회
│   │   ├── RIGHT(assembly_code, 3) = XXX (끝 3자리 검색)
│   │   ├── 7단계 공정 상태 분석 (Fit-up→PACKING)
│   │   └── 완료된 공정, 진행상태, 최종날짜 계산
│   │
│   ├── POST /api/inspection-requests (토큰 필요)
│   │   ├── 여러 assembly_code 배치 처리
│   │   ├── inspection_type, request_date 저장
│   │   └── requested_by_user_id, requested_by_name 기록
│   │
│   └── GET /api/inspection-requests?date=YYYY-MM-DD (토큰 필요)
│       ├── 사용자 권한 레벨 확인
│       ├── Level 1: 본인 신청만 (WHERE requested_by_user_id = current_user)
│       ├── Level 3+: 전체 신청 (모든 사용자)
│       └── 날짜 형식 변환 (GMT → YYYY-MM-DD)
│
└── 🔧 유틸리티 함수
    ├── get_db_connection() → MySQL 연결
    └── 날짜 형식 변환 (req_item 처리)
```

---

### ⚙️ **환경설정 & 데이터**

#### 📄 **config_env.py** ⭐ (환경별 설정)
```
config_env.py
├── get_environment() → 'home' or 'company' 감지 (WORK_ENV 환경변수)
├── get_db_config() → DB 연결 설정
│   ├── 집: 192.168.0.5 (회사 DB 원격 접속)
│   └── 회사: localhost (로컬 DB)
└── get_server_config() → Flask 서버 설정 (포트 5001)
```

#### 📄 **import_data.py** (데이터 가져오기)
```
import_data.py
├── assembly_data.xlsx 읽기 ('process' 시트)
├── N/A 처리 (1900-01-01로 변환 - 생략된 공정)
├── 빈 셀 처리 (NULL로 유지 - 미완료 공정)
└── MySQL assembly_items 테이블에 INSERT
```

#### 📄 **assembly_data.xlsx** (원본 데이터)
```
Excel 파일 구조:
├── process 시트 (메인 데이터 - 373개 조립품)
├── bom 시트 (자재 명세서)
└── arup 시트 (기타 정보)
```

---

### 📊 **데이터베이스 (MySQL)**

#### 🗄️ **field_app_db**
```
MySQL Tables:
├── assembly_items (실제 조립품 데이터 - 373개)
│   ├── id, assembly_code, zone, item
│   ├── fit_up_date, nde_date, vidi_date
│   ├── galv_date, shot_date, paint_date, packing_date
│   └── 날짜 규칙: NULL(미완료), 1900-01-01(생략), 실제날짜(완료)
│
└── inspection_requests (검사신청 데이터)
    ├── id (AUTO_INCREMENT)
    ├── assembly_code (조립품 코드)
    ├── inspection_type (검사 타입: NDE, VIDI, GALV...)
    ├── requested_by_user_id (신청자 ID)
    ├── requested_by_name (신청자 이름)
    ├── request_date (검사 요청 날짜)
    └── created_at (신청 생성 시간)
```

---

## 🔄 **상세 동작 흐름**

### 1️⃣ **로그인 플로우**
```
사용자 입력 (l1/l1) 
→ login_screen.dart:_hashPassword() → SHA256 해싱
→ login_screen.dart:_callLoginAPI() → HTTP POST /api/login
→ flask_server.py: 테스트 사용자 검증
→ JWT 토큰 생성 (24시간 유효)
→ login_screen.dart: SharedPreferences에 토큰 저장
→ main.dart:AssemblySearchScreen으로 이동
```

### 2️⃣ **ASSEMBLY 검색 플로우**
```
숫자 입력 (예: 201)
→ main.dart:_onNumberPressed() → _assemblyCode 상태 업데이트
→ 검색 버튼 클릭
→ main.dart:_onSearchPressed() → HTTP GET /api/assemblies?search=201
→ flask_server.py: RIGHT(assembly_code, 3) = '201' 쿼리
→ 7단계 공정 상태 분석 (완료/진행중/대기)
→ JSON 반환 → main.dart에서 리스트 표시
```

### 3️⃣ **검사신청 플로우**
```
검색 결과 체크 → LIST UP 버튼
→ main.dart:SavedListScreen 이동
→ 날짜 선택 (기본: 내일)
→ 항목 선택 → 검사신청 버튼
→ main.dart:_requestInspection() → 공정 검증 (같은 공정끼리만)
→ main.dart:_submitInspectionRequest() → JWT 토큰으로 API 호출
→ HTTP POST /api/inspection-requests
→ flask_server.py: MySQL에 배치 INSERT
→ 성공 시 해당 항목들 LIST에서 제거
```

### 4️⃣ **검사신청 확인 플로우**
```
검사신청 확인 버튼 클릭
→ main.dart:InspectionRequestScreen 이동
→ main.dart:_loadInspectionRequests() → JWT 토큰으로 API 호출
→ HTTP GET /api/inspection-requests?date=2025-07-16
→ flask_server.py: 사용자 레벨 확인
→ Level 1: WHERE requested_by_user_id = current_user
→ Level 3+: 전체 검사신청 조회
→ 날짜 형식 변환 (GMT → YYYY-MM-DD)
→ main.dart에서 검사신청 목록 표시
```

---

## 🌐 **API 엔드포인트 맵**

### **서버 주소**: `http://192.168.0.5:5001`

| 메소드 | 엔드포인트 | 인증 | 기능 | 사용 화면 |
|--------|------------|------|------|-----------|
| POST | `/api/login` | ❌ | 로그인 인증, JWT 토큰 발급 | login_screen.dart |
| GET | `/api/assemblies?search=XXX` | ❌ | ASSEMBLY 검색 (끝 3자리) | main.dart |
| POST | `/api/inspection-requests` | ✅ | 검사신청 생성 (배치) | main.dart |
| GET | `/api/inspection-requests?date=YYYY-MM-DD` | ✅ | 검사신청 조회 (레벨별) | main.dart |

---

## 👥 **사용자 권한 시스템**

### **테스트 계정**
| 레벨 | 계정 | 권한 | 기능 |
|------|------|------|------|
| Admin | a/a | 전체 | 모든 기능 사용 |
| Level 1 | l1/l1 | 외부업체 | 검색, LIST UP, 검사신청, 본인 신청만 확인 |
| Level 3 | l3/l3 | DSHI 현장직원 | Level 1 + 롤백, PDF, 전체 검사신청 확인 |
| Level 5 | l5/l5 | DSHI 시스템관리자 | Level 3 + 관리자 기능 |

---

## 🏗️ **7단계 공정 워크플로우**

```
Fit-up → NDE → VIDI → GALV → SHOT → PAINT → PACKING
  ↓       ↓      ↓       ↓       ↓       ↓        ↓
 NDE검사  VIDI검사 GALV검사 SHOT검사 PAINT검사 PACKING검사  완료
```

### **공정 상태 규칙**
- **NULL**: 미완료 공정 (아직 진행 안됨)
- **1900-01-01**: 생략된 공정 (해당 제품에 불필요)
- **실제 날짜**: 완료된 공정

---

## 📁 **프로젝트 파일 구조**

```
DSHI_RPA/APP/
├── 📱 dshi_field_app/ (Flutter 앱)
│   ├── lib/
│   │   ├── main.dart ⭐
│   │   └── login_screen.dart ⭐
│   ├── pubspec.yaml
│   └── android/app/src/main/AndroidManifest.xml
├── 🔧 flask_server.py ⭐
├── ⚙️ config_env.py ⭐
├── 📊 import_data.py
├── 📄 assembly_data.xlsx
├── 📖 README.md
└── 📚 docs/
    ├── development_r0.md
    ├── app_structure_map.md ⭐ (이 파일)
    └── work_rules.md
```

---

## 🔄 **개발 환경 설정**

### **회사에서 작업**
```bash
# 환경변수 설정 안함 (기본값)
python flask_server.py
```

### **집에서 작업**
```bash
# 환경변수 설정
set WORK_ENV=home
python flask_server.py
```

### **Flutter 앱 실행**
```bash
cd dshi_field_app
flutter run
```

---

## 📝 **주요 특징**

### ✅ **구현 완료된 기능**
- 🔐 JWT 토큰 기반 인증 시스템
- 🔍 ASSEMBLY 검색 (끝 3자리 번호)
- 📋 LIST UP 시스템 (다중 선택, 저장)
- 📅 검사신청 (날짜별, 공정별)
- 📊 검사신청 확인 (레벨별 권한, 실시간 업데이트)
- 🌐 회사/집 환경 자동 전환
- 📱 한국어 지원, 태블릿 최적화 UI

### 🚧 **향후 구현 예정**
- 🔄 롤백 기능 (Level 3+)
- 📄 PDF 도면 연동 (Level 3+)
- 📤 엑셀 업로드 (Level 3+)
- 📈 관리자 대시보드 (Level 4-5)

---

*📅 최종 업데이트: 2025-07-15*  
*🎯 상태: 검사신청 시스템 완전 구현 완료*
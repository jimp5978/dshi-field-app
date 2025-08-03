# DSHI RPA 프로젝트 완전 가이드

> 📅 **최종 업데이트**: 2025-07-21  
> 🎯 **상태**: 2개 프로젝트 모두 Production Ready  
> 🌐 **서버**: `http://203.251.108.199:5001` (공인 IP - 외부 접속 가능)

## 📋 프로젝트 개요

**DSHI RPA**는 현장 관리와 데이터 분석을 위한 통합 시스템으로, 2개의 주요 프로젝트로 구성됩니다:

1. **Flutter 현장 관리 앱** - 현장 작업자용 모바일 시스템 (완성)
2. **Sinatra Dashboard 시스템** - 사무실 관리자용 데이터 분석 (완성)

### 🎯 핵심 특징
- **JWT 기반 인증** 및 권한별 접근 제어 (Level 1-5)
- **7단계 공정 관리** (Fit-up → PACKING)
- **3단계 검사신청 워크플로우** (대기중 → 승인됨 → 확정됨)
- **실시간 데이터 분석** 및 진행률 추적

### 🏗️ **최종 완성된 아키텍처**
```
📱 Flutter 앱 ←→ 🔧 Flask API (포트 5001) ←→ 🗄️ MySQL DB
                                                    ↕️
📊 Sinatra Dashboard (포트 5002) ←→ 🐍 dashboard_api.py ←→ (동일한 MySQL)
```

**구조적 설계 철학:**
- **분리된 책임**: 현장 운영(Flutter+Flask) vs 데이터 분석(Sinatra+Python)
- **데이터 일관성**: 단일 MySQL DB를 통한 실시간 데이터 공유
- **기술 최적화**: 각 계층별 최적 기술 스택 선택
- **확장성**: 독립적 스케일링 및 유지보수 가능

---

## 🗂️ 전체 파일 구조

```
DSHI_RPA/APP/
├── 📱 dshi_field_app/ (Flutter 앱 - Frontend)
│   ├── lib/
│   │   ├── main.dart ⭐ (1,900+ 줄 - 앱 핵심 로직)
│   │   │   ├── DSHIFieldApp (앱 전체 설정)
│   │   │   ├── AssemblySearchScreen (메인 검색 화면)
│   │   │   │   ├── 숫자 키패드 (0-9, DEL, ←)
│   │   │   │   ├── 검색 결과 리스트 (체크박스 선택)
│   │   │   │   └── 5단계 검색 상태 관리
│   │   │   ├── SavedListScreen (저장된 리스트 화면)
│   │   │   │   ├── 전체선택/삭제 기능
│   │   │   │   ├── 날짜 선택 달력
│   │   │   │   └── 검사신청 처리
│   │   │   └── InspectionRequestScreen (검사신청 확인)
│   │   │       ├── 레벨별 권한 제어
│   │   │       ├── 신청자/공정별 필터링
│   │   │       └── 3단계 상태 관리
│   │   ├── login_screen.dart ⭐ (400+ 줄 - 로그인 전용)
│   │   │   ├── JWT 토큰 기반 인증
│   │   │   ├── SHA256 패스워드 해싱
│   │   │   ├── 계정 정보 저장 (기억하기)
│   │   │   └── 권한별 화면 라우팅
│   │   └── admin_dashboard_screen.dart ⭐ (800+ 줄 - 관리자 전용)
│   │       ├── 사용자 관리 (생성/수정/삭제)
│   │       ├── 권한별 색상 구분
│   │       ├── 서버 설정 (Admin 전용)
│   │       └── 완전 삭제 기능
│   ├── pubspec.yaml (패키지 의존성)
│   │   ├── http: ^1.1.0 (API 통신)
│   │   ├── shared_preferences: ^2.2.2 (토큰 저장)
│   │   ├── crypto: ^3.0.3 (SHA256 해싱)
│   │   └── intl: ^0.19.0 (날짜 포맷팅)
│   └── android/app/src/main/AndroidManifest.xml
│       └── INTERNET 권한 설정
│
├── 📊 dshi_dashboard/ (Sinatra Dashboard - 경량 분석 시스템)
│   ├── Gemfile ⭐ (최소화된 의존성 - 4개 gem만)
│   │   ├── sinatra (경량 웹 프레임워크)
│   │   ├── webrick (개발용 서버)
│   │   ├── rackup (Sinatra 실행 환경)
│   │   └── net-http (Python API 통신)
│   ├── run_dashboard.rb ⭐ (메인 대시보드 애플리케이션)
│   │   ├── DSHIDashboard 클래스 (API 연동 로직)
│   │   ├── 라우트 정의 (/, /api/stats, /health)
│   │   └── Python API 연동 처리
│   ├── views/index.erb ⭐ (대시보드 UI 템플릿)
│   │   ├── 반응형 CSS Grid 레이아웃
│   │   ├── 실시간 진행률 시각화
│   │   └── 자동 새로고침 JavaScript
│   └── dashboard_api.py ⭐ (Python 데이터 브리지)
│       ├── Flask API 연동 및 MySQL 데이터 분석
│       ├── 실시간 통계 계산 (373개 조립품)
│       └── 모의 데이터 생성 (API 실패시)
│
├── 🔧 flask_server.py ⭐ (740+ 줄 - API 서버)
│   ├── Flask + CORS + JWT 설정
│   ├── MySQL 연결 및 쿼리 처리
│   ├── 토큰 기반 인증 시스템
│   ├── Admin API (/api/admin/*)
│   └── 검사신청 워크플로우 처리
│
├── ⚙️ config_env.py ⭐ (환경별 설정)
│   ├── 환경 감지 (home/company)
│   ├── DB 연결 설정 (192.168.0.5/localhost)
│   └── 서버 설정 (포트 5001)
│
├── 📊 import_data.py (데이터 가져오기)
│   ├── assembly_data.xlsx 읽기
│   ├── N/A → 1900-01-01 변환
│   └── MySQL INSERT 처리
│
├── 📄 assembly_data.xlsx (원본 데이터 - 373개 조립품)
│   ├── process 시트 (서브 데이터)
│   ├── bom 시트 (자재 데이터)
│   └── arup 시트 (메인 데이터)
│
├── 📄 create_users_table.sql (사용자 테이블 생성)
│
├── 📖 README.md
└── 📚 docs/
    ├── development_r0.md
    ├── app_structure_map.md
    ├── project_status.md
    ├── project_complete_guide.md (이 파일)
    └── work_rules.md
```

---

## 📱 Flutter 현장 관리 앱

### 🏗️ 기본 정보
- **위치**: `E:\DSHI_RPA\APP\dshi_field_app\`
- **기술스택**: Flutter + Dart
- **백엔드**: Flask API (포트 5001)
- **데이터베이스**: MySQL `field_app_db`
- **서버**: `http://203.251.108.199:5001` (공인 IP)

### ✅ 완성된 핵심 기능
- **JWT 기반 인증**: 완전 구현
- **권한별 접근 제어**: Level 1, 3, 4, 5
- **ASSEMBLY 검색**: 끝 3자리 번호 검색
- **LIST UP 시스템**: 다중선택, 저장, 삭제
- **검사신청**: 날짜별 구분, 3단계 워크플로우
- **Admin Dashboard**: Level 5+ 전용 사용자 관리
- **UI/UX**: 태블릿 최적화 완료

### 📱 화면 구성

#### 🔍 **AssemblySearchScreen** (메인 화면)
- **검색 기능**: 끝 3자리 번호로 조립품 검색
- **키패드 UX**: 큰 숫자 키패드 + 검색 버튼 지원
- **상태 관리**: 초기/로딩/성공/빈결과/에러 5단계
- **다중 선택**: 체크박스 기반 항목 선택

#### 📋 **SavedListScreen** (저장 리스트)
- **리스트 관리**: 전체선택/해제, 개별/전체 삭제
- **검사신청**: 날짜 선택 + 공정별 검증
- **배치 처리**: 여러 항목 동시 신청

#### 📊 **InspectionRequestScreen** (검사신청 확인)
- **권한별 조회**: Level 1(본인), Level 3+(전체)
- **고급 필터링**: 신청자별, 공정별, 날짜별
- **상태 관리**: 승인/확정/취소 처리

#### 🔧 **AdminDashboardScreen** (관리자 전용)
- **사용자 관리**: CRUD 완전 구현
- **권한 제어**: Level 5+ 접근 제한
- **서버 설정**: URL 변경 및 연결 테스트

---

## 📊 Sinatra Dashboard 시스템

### 🏗️ 기본 정보
- **위치**: `E:\DSHI_RPA\APP\dshi_dashboard\`
- **기술스택**: Sinatra + WebRick + Python API 브리지
- **목적**: 경량 대시보드로 데이터 분석 및 시각화
- **주요 사용자**: Level 4 (DSHI 관리자)
- **포트**: 5002번 (Sinatra 서버)

### ✅ 완성된 기능
- **Sinatra 대시보드**: 완전 구현 (ERB 템플릿)
- **반응형 디자인**: CSS Grid + 모바일 최적화
- **Python API 연동**: `dashboard_api.py`로 실시간 MySQL 데이터 연동
- **Native Extension 우회**: 최소 4개 gem으로 안정적 운영
- **자동 복구**: API 실패시 모의 데이터 대체

### 📈 대시보드 기능
- **전체 현황**: 조립품 진행률 실시간 표시
- **7단계 공정 완료율**: Fit-up → PACKING 진행률 시각화
- **상태별 분포**: 완료/진행중/대기/지연 실시간 통계
- **이슈 추적**: 주요 문제점 및 알림 시스템
- **자동 새로고침**: 5분마다 데이터 업데이트

---

## 🔧 백엔드 시스템

### 🌐 **Flask API Server** (`flask_server.py`)
- **인증 시스템**: JWT 토큰 (24시간 유효)
- **데이터베이스**: MySQL 연결 및 트랜잭션 처리
- **API 보안**: token_required 데코레이터
- **환경 설정**: config_env.py 연동

### 🗄️ **MySQL 데이터베이스** (`arup_ecs_db`)
```
Tables (8개):
├── users (사용자 관리)
│   ├── id, username, password_hash
│   ├── full_name, company, permission_level
│   └── is_active, created_at
├── assembly_items
│   ├── assembly_code, zone, item, weight_(net)
│   └── 8단계 공정 날짜 (fit_up_date → ARUP_PAINT)
├── inspection_requests (검사신청)
│   ├── assembly_code, inspection_type
│   ├── requested_by_user_id, requested_by_name
│   ├── request_date, status
│   └── approved_at, confirmed_at
├── dshi_staff (DSHI 직원 정보)
├── external_users (외부업체 사용자)
├── process_definitions (공정 정의)
├── process_logs (공정 로그)
└── rollback_reasons (롤백 사유)
```

### 🌐 **API 엔드포인트**

| 메소드 | 엔드포인트 | 인증 | 기능 | 권한 |
|--------|------------|------|------|------|
| POST | `/api/login` | ❌ | JWT 토큰 발급 | 모든 사용자 |
| GET | `/api/assemblies?search=XXX` | ❌ | 조립품 검색 | 모든 사용자 |
| POST | `/api/inspection-requests` | ✅ | 검사신청 생성 | Level 1+ |
| GET | `/api/inspection-requests` | ✅ | 검사신청 조회 | Level 1+ |
| GET | `/api/inspection-requests/requesters` | ✅ | 신청자 목록 | Level 3+ |
| PUT | `/api/inspection-requests/{id}/approve` | ✅ | 검사신청 승인 | Level 3+ |
| PUT | `/api/inspection-requests/{id}/confirm` | ✅ | 검사신청 확정 | Level 3+ |
| DELETE | `/api/inspection-requests/{id}` | ✅ | 검사신청 취소 | Level별 권한 |
| GET | `/api/admin/users` | ✅ | 사용자 목록 | Level 5+ |
| POST | `/api/admin/users` | ✅ | 사용자 생성 | Level 5+ |
| PUT | `/api/admin/users/{id}` | ✅ | 사용자 수정 | Level 5+ |
| DELETE | `/api/admin/users/{id}` | ✅ | 사용자 비활성화 | Level 5+ |
| DELETE | `/api/admin/users/{id}/delete-permanently` | ✅ | 사용자 완전 삭제 | Level 5+ |

---

## 🔐 권한 시스템 및 워크플로우

### 👥 **사용자 권한 시스템**

| 레벨 | 역할 | 주요 기능 |
|------|------|----------|
| **Level 1** | 사내업체 | 검색, LIST UP, 검사신청, 본인 신청만 확인 |
| **Level 3** | DSHI 현장직원 | Level 1 + 전체 검사신청 관리, 승인/확정 처리 |
| **Level 4** | DSHI 관리자 | 데이터 분석 전용 (Sinatra Dashboard 접근) |
| **Level 5** | 시스템관리자 | Level 3 + Admin Dashboard, 사용자 관리 |

### 🔐 **보안 특징**
- **데이터베이스 기반**: 모든 계정 MySQL `users` 테이블 관리
- **동적 관리**: Admin Dashboard에서 실시간 사용자 생성/수정
- **권한 제어**: JWT 토큰 기반 API 접근 제어
- **자기 보호**: 관리자가 자기 자신 삭제 방지

### 🔄 **핵심 워크플로우**

#### 1️⃣ **7단계 공정 흐름** (기본공정흐름)
```
Fit-up → NDE → VIDI → GALV → SHOT → PAINT → PACKING
```

ARUP 공정 흐름
FIT-UP -> FINAL -> ARUP_FINAL -> GALV -> ARUP_GALV -> SHOT -> PAINT -> ARUP_PAINT

#### 2️⃣ **검사신청 3단계 워크플로우**
```
대기중 (🟡) → 승인됨 (🟢) → 확정됨 (🔵)
     ↓            ↓            ↓
   Level 1      Level 3+     Level 3+
 (본인만 취소)   (승인 처리)   (확정 처리)
```

#### 3️⃣ **권한별 접근 제어**
- **Level 1**: 본인 신청만 조회, 대기중 상태만 취소
- **Level 3+**: 전체 조회/관리, 모든 상태 처리, 필터링
- **Level 4**: Sinatra Dashboard 데이터 분석 접근
- **Level 5+**: Admin Dashboard 접근

---

## 🚀 개발 및 배포 환경

### 💻 **기술 환경**
- **OS**: Windows (Git Bash)
- **Flutter**: 3.32.5
- **Ruby on Rails**: 8.0
- **Node.js**: v22.17.0
- **MySQL**: 8.0.40
- **Python**: 3.x (Flask)

### ⚙️ **MCP 서버** (4개 설치)
1. **mcp-installer**: MCP 관리 도구
2. **playwright-stealth**: 브라우저 자동화 (24개 도구)
3. **git**: Git 저장소 관리
4. **mysql**: MySQL 데이터베이스 조작

### 🌐 **네트워크 설정**
- **Flask API**: `203.251.108.199:5001` (공인 IP - 외부 접속)
- **Sinatra Dashboard**: `localhost:5002` (로컬 대시보드)
- **로컬 Flask**: `192.168.0.5:5001` (같은 와이파이)
- **개발**: `localhost:5001` (Flask), `localhost:5002` (Sinatra)

### 🔧 **서버 실행**
```bash
# Flask 서버 (API 백엔드)
python flask_server.py
# → http://203.251.108.199:5001 접속 가능

# Sinatra 서버 (대시보드)
cd dshi_dashboard
ruby run_dashboard.rb
# → http://localhost:5002 접속 가능
```

### 📱 **Flutter 개발 및 배포**
```bash
# 개발 실행
cd dshi_field_app
flutter run

# APK 빌드 (배포용)
flutter build apk --release --split-per-abi
# → app-arm64-v8a-release.apk (8.3MB) 권장
```

---

## 📋 프로젝트 현재 상태

### ✅ **완성된 영역**
- **Flutter 앱**: UI/UX 100% + 기본기능 100%
- **인증시스템**: JWT 토큰 기반 완전 구현
- **데이터베이스**: MySQL 연동 및 관리 완료
- **Sinatra 대시보드**: 경량 프레임워크 + Python API 연동 완전 구현
- **권한 시스템**: 레벨별 접근 제어 완료
- **검사신청**: 3단계 워크플로우 완료

### 📊 **시스템 상태**
- **Flutter 앱**: Production Ready ✅
- **Flask API**: 정상 작동 (포트 5001) ✅
- **Sinatra Dashboard**: 정상 작동 (포트 5002) ✅
- **MySQL DB**: 8개 테이블, 373개 데이터 ✅

### 📝 **최근 주요 업데이트** (2025-07-16 ~ 2025-07-21)

#### ✅ **Admin Dashboard 완전 구현**
- Level 5+ 전용 사용자 관리 시스템
- 실시간 사용자 생성/수정/삭제/비활성화
- 권한별 색상 구분 및 완전 삭제 기능

#### ✅ **Sinatra Dashboard 시스템 구축** (2025-07-21)
- **기술적 해결**: Ruby 3.3.8 + GCC 15 호환성 문제 해결
- **Native Extension 우회**: Rails → Sinatra로 경량화
- **최소 의존성**: 4개 gem만으로 안정적 운영
- **실시간 연동**: dashboard_api.py를 통한 MySQL 데이터 브리지

#### ✅ **데이터베이스 기반 사용자 관리**
- 하드코딩된 계정 정보 완전 제거
- MySQL `users` 테이블 기반 동적 관리
- 실시간 변경사항 로그인 시스템 반영

#### ✅ **검색 기능 개선**
- 5단계 검색 상태 관리 (초기/로딩/성공/빈결과/에러)
- 향상된 에러 처리 및 복구 지원
- 사용자 친화적 피드백 시스템

#### ✅ **보안 및 권한 강화**
- JWT 토큰 기반 완전한 권한 분리
- 트랜잭션 기반 데이터 무결성
- 자기 보호 메커니즘 구현

---

*📅 최종 업데이트: 2025-07-21*  
*🎯 상태: 2개 프로젝트 모두 Production Ready - 실제 현장 운영 가능*  
*🏗️ 아키텍처: Flutter+Flask (현장) + Sinatra+Python (분석) + MySQL (데이터)*
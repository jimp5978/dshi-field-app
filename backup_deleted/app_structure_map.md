# DSHI Field Pad 앱 구조 맵

> 📅 **업데이트**: 2025-07-16  
> 🎯 **상태**: Admin Dashboard 완전 구현 - 데이터베이스 기반 사용자 관리 시스템 완료  
> 🌐 **서버**: `http://203.251.108.199:5001` (공인 IP - 외부 접속 가능)

## 📋 개요

**DSHI Field Pad**는 현장에서 사용하는 검사 관리 앱으로, Flutter 프론트엔드와 Flask 백엔드로 구성된 완성도 높은 production-ready 시스템입니다.

### 🎯 핵심 기능
- **JWT 기반 인증** (데이터베이스 완전 관리)
- **7단계 공정 관리** (Fit-up → PACKING)
- **3단계 검사신청 워크플로우** (대기중 → 승인됨 → 확정됨)
- **권한별 접근 제어** (Level 1-5)
- **Admin Dashboard** (Level 5+ 전용)

---

## 🗂️ 프로젝트 파일 구조

```
DSHI_RPA/APP/
├── 📱 dshi_field_app/ (Flutter 앱 - Frontend)
│   ├── lib/
│   │   ├── main.dart ⭐ (1900+ 줄 - 앱 핵심)
│   │   │   ├── DSHIFieldApp (앱 전체 설정)
│   │   │   ├── AssemblySearchScreen (메인 검색 화면)
│   │   │   │   ├── 숫자 키패드 (0-9, DEL, ←)
│   │   │   │   ├── 검색 결과 리스트 (체크박스)
│   │   │   │   └── 검색 상태 관리 (5단계)
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
    ├── app_structure_map.md (이 파일)
    └── work_rules.md
```

---

## 📱 Frontend 구성요소

### 🔍 **AssemblySearchScreen** (메인 화면)
- **검색 기능**: 끝 3자리 번호로 조립품 검색
- **키패드 UX**: 큰 숫자 키패드 + 검색 버튼 지원
- **상태 관리**: 초기/로딩/성공/빈결과/에러 5단계
- **다중 선택**: 체크박스 기반 항목 선택

### 📋 **SavedListScreen** (저장 리스트)
- **리스트 관리**: 전체선택/해제, 개별/전체 삭제
- **검사신청**: 날짜 선택 + 공정별 검증
- **배치 처리**: 여러 항목 동시 신청

### 📊 **InspectionRequestScreen** (검사신청 확인)
- **권한별 조회**: Level 1(본인), Level 3+(전체)
- **고급 필터링**: 신청자별, 공정별, 날짜별
- **상태 관리**: 승인/확정/취소 처리

### 🔧 **AdminDashboardScreen** (관리자 전용)
- **사용자 관리**: CRUD 완전 구현
- **권한 제어**: Level 5+ 접근 제한
- **서버 설정**: URL 변경 및 연결 테스트

---

## 🔧 Backend 구성요소

### 🌐 **Flask Server** (`flask_server.py`)
- **인증 시스템**: JWT 토큰 (24시간 유효)
- **데이터베이스**: MySQL 연결 및 트랜잭션 처리
- **API 보안**: token_required 데코레이터
- **환경 설정**: config_env.py 연동

### 📊 **데이터베이스** (MySQL: `field_app_db`)
```
Tables:
├── users (사용자 관리)
│   ├── id, username, password_hash
│   ├── full_name, company, permission_level
│   └── is_active, created_at
├── assembly_items (조립품 데이터)
│   ├── assembly_code, zone, item
│   └── 7단계 공정 날짜 (fit_up_date → packing_date)
└── inspection_requests (검사신청)
    ├── assembly_code, inspection_type
    ├── requested_by_user_id, requested_by_name
    ├── request_date, status
    └── approved_at, confirmed_at
```

---

## 🌐 API 엔드포인트

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

## 👥 사용자 권한 시스템

| 레벨 | 권한 | 주요 기능 |
|------|------|----------|
| **Level 1** | 사내업체 | 검색, LIST UP, 검사신청, 본인 신청만 확인 |
| **Level 3** | DSHI 현장직원 | Level 1 + 전체 검사신청 관리, 승인/확정 처리 |
| **Level 5** | DSHI 시스템관리자 | Level 3 + Admin Dashboard, 사용자 관리 |

### 🔐 **보안 특징**
- **데이터베이스 기반**: 모든 계정 MySQL `users` 테이블 관리
- **동적 관리**: Admin Dashboard에서 실시간 사용자 생성/수정
- **권한 제어**: JWT 토큰 기반 API 접근 제어
- **자기 보호**: 관리자가 자기 자신 삭제 방지

---

## 🔄 핵심 워크플로우

### 1️⃣ **7단계 공정 흐름**
```
Fit-up → NDE → VIDI → GALV → SHOT → PAINT → PACKING
```

### 2️⃣ **검사신청 3단계 워크플로우**
```
대기중 (🟡) → 승인됨 (🟢) → 확정됨 (🔵)
     ↓            ↓            ↓
   Level 1      Level 3+     Level 3+
 (본인만 취소)   (승인 처리)   (확정 처리)
```

### 3️⃣ **권한별 접근 제어**
- **Level 1**: 본인 신청만 조회, 대기중 상태만 취소
- **Level 3+**: 전체 조회/관리, 모든 상태 처리, 필터링
- **Level 5+**: Admin Dashboard 접근

---

## 🚀 개발 및 배포

### **서버 실행**
```bash
# Flask 서버 시작
python flask_server.py
# → http://203.251.108.199:5001 접속 가능
```

### **Flutter 개발**
```bash
cd dshi_field_app
flutter run
```

### **APK 배포**
```bash
# 모든 아키텍처용 APK 빌드
flutter build apk --release --split-per-abi
# → app-arm64-v8a-release.apk (8.3MB) 권장
```

### **네트워크 설정**
- **공인 IP**: `203.251.108.199:5001` (외부 접속)
- **로컬**: `192.168.0.5:5001` (같은 와이파이)
- **개발**: `localhost:5001`

---

## 📝 최근 주요 업데이트 (2025-07-16)

### ✅ **Admin Dashboard 완전 구현**
- Level 5+ 전용 사용자 관리 시스템
- 실시간 사용자 생성/수정/삭제/비활성화
- 권한별 색상 구분 및 완전 삭제 기능

### ✅ **데이터베이스 기반 사용자 관리**
- 하드코딩된 계정 정보 완전 제거
- MySQL `users` 테이블 기반 동적 관리
- 실시간 변경사항 로그인 시스템 반영

### ✅ **검색 기능 개선**
- 5단계 검색 상태 관리 (초기/로딩/성공/빈결과/에러)
- 향상된 에러 처리 및 복구 지원
- 사용자 친화적 피드백 시스템

### ✅ **보안 및 권한 강화**
- JWT 토큰 기반 완전한 권한 분리
- 트랜잭션 기반 데이터 무결성
- 자기 보호 메커니즘 구현

---

*📅 최종 업데이트: 2025-07-16*  
*🎯 상태: Production Ready - 실제 현장 운영 가능*
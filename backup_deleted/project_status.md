# DSHI RPA 프로젝트 현재 상태

> 📅 최종 업데이트: 2025-07-20  
> 🎯 목적: 전체 프로젝트 구조 및 완성된 기능 현황  

## 📋 프로젝트 개요

**2개의 주요 프로젝트**:
1. **Flutter 현장 관리 앱** - 현장 작업자용 모바일 시스템
2. **Rails Dashboard 시스템** - 사무실 관리자용 데이터 분석 (Flask → Rails 전환)

---

## 📱 프로젝트 1: Flutter 현장 관리 앱

### 🏗️ 기본 정보
- **위치**: `E:\DSHI_RPA\APP\dshi_field_app\`
- **기술스택**: Flutter + Flask 백엔드 + MySQL
- **서버**: `http://203.251.108.199:5001` (공인 IP)
- **데이터베이스**: MySQL `field_app_db`

### ✅ 완성된 기능 (Production Ready)
- **JWT 기반 인증**: 완전 구현
- **권한별 접근 제어**: Level 1, 3, 4, 5
- **ASSEMBLY 검색**: 끝 3자리 번호 검색
- **LIST UP 시스템**: 다중선택, 저장, 삭제
- **검사신청**: 날짜별 구분, 3단계 워크플로우
- **Admin Dashboard**: Level 5+ 전용 사용자 관리
- **UI/UX**: 태블릿 최적화 완료

### 🔐 권한 시스템
| 레벨 | 역할 | 주요 기능 |
|------|------|----------|
| Level 1 | 사내업체 | 검색, LIST UP, 검사신청 |
| Level 3 | DSHI 현장직원 | Level 1 + 승인/확정 처리 |
| Level 4 | DSHI 관리자 | 데이터 분석 전용 |
| Level 5 | 시스템관리자 | 전체 + 사용자 관리 |

### 🗄️ 데이터베이스 (MySQL)
```
Tables (8개):
├── users (사용자 관리)
├── assembly_items (조립품 데이터)
├── inspection_requests (검사신청)
├── dshi_staff (DSHI 직원)
├── external_users (외부업체)
├── process_definitions (공정 정의)
├── process_logs (공정 로그)
└── rollback_reasons (롤백 사유)
```

### 🔄 7단계 공정 워크플로우
```
Fit-up → NDE → VIDI → GALV → SHOT → PAINT → PACKING
```

### 🌐 API 엔드포인트 (Flask)
| 메소드 | 엔드포인트 | 인증 | 기능 |
|--------|------------|------|------|
| POST | `/api/login` | ❌ | JWT 토큰 발급 |
| GET | `/api/assemblies?search=XXX` | ❌ | 조립품 검색 |
| POST | `/api/inspection-requests` | ✅ | 검사신청 생성 |
| GET | `/api/inspection-requests` | ✅ | 검사신청 조회 |
| PUT | `/api/inspection-requests/{id}/approve` | ✅ | 승인 처리 |
| PUT | `/api/inspection-requests/{id}/confirm` | ✅ | 확정 처리 |
| GET | `/api/admin/users` | ✅ | 사용자 관리 |

---

## 📊 프로젝트 2: Rails Dashboard 시스템

### 🏗️ 기본 정보
- **위치**: `E:\DSHI_RPA\APP\dshi_dashboard\`
- **기술스택**: Ruby on Rails 8.0 + SQLite + Python API
- **목적**: 사무실 관리자용 데이터 분석
- **주요 사용자**: Level 4 (DSHI 관리자)
- **포트**: 3000번 (Rails 서버)

### ✅ 완성된 기능
- **Rails 8.0 대시보드**: 완전 구현 (ERB 템플릿)
- **반응형 디자인**: CSS Variables & clamp() 사용
- **Python API 연동**: `dashboard_api.py`로 Flask 서버 데이터 연동
- **데이터 분석**: 공정별, 업체별, 기간별 분석
- **UI/UX 최적화**: 사무실 환경 맞춤

### 📈 대시보드 기능
- **필터 시스템**: 공정/업체/기간별 다중선택
- **진행률 분석**: 7단계 공정별 완료율
- **병목 분석**: 지연 공정 식별
- **실시간 업데이트**: 6시간 주기 자동 새로고침

---

## 🛠️ 개발 환경

### 💻 기술 환경
- **OS**: Windows (Git Bash)
- **Node.js**: v22.17.0
- **Flutter**: 3.32.5
- **MySQL**: 8.0.40
- **서버**: 공인 IP `203.251.108.199`

### ⚙️ MCP 서버 (4개 설치)
1. **mcp-installer**: MCP 관리 도구
2. **playwright-stealth**: 브라우저 자동화 (24개 도구)
3. **git**: Git 저장소 관리
4. **mysql**: MySQL 데이터베이스 조작

### 📁 핵심 파일 구조
```
DSHI_RPA/APP/
├── dshi_field_app/ (Flutter 앱)
│   ├── lib/main.dart (1900+ 줄, 앱 핵심)
│   ├── lib/login_screen.dart (400+ 줄)
│   └── lib/admin_dashboard_screen.dart (800+ 줄)
├── dshi_dashboard/ (Rails 대시보드)
│   ├── app/views/dashboard/ (ERB 템플릿들)
│   ├── dashboard_api.py (Python API 연동)
│   └── config/routes.rb (라우팅 설정)
├── flask_server.py (740+ 줄, API 서버)
├── config_env.py (환경별 설정)
├── assembly_data.xlsx (373개 조립품 데이터)
└── docs/ (프로젝트 문서)
```

---

## 🚀 배포 및 운영

### 📱 Flutter 앱
```bash
# APK 빌드
flutter build apk --release --split-per-abi
# → app-arm64-v8a-release.apk (8.3MB)
```

### 🌐 서버 실행
```bash
# Flask 서버 (API 백엔드)
python flask_server.py
# → http://203.251.108.199:5001 접속 가능

# Rails 서버 (대시보드)
cd dshi_dashboard
rails server
# → http://localhost:3000 접속 가능
```

### 🗄️ 네트워크 설정
- **Flask API**: `203.251.108.199:5001` (공인 IP - 외부 접속)
- **Rails Dashboard**: `localhost:3000` (로컬 대시보드)
- **로컬 Flask**: `192.168.0.5:5001` (같은 와이파이)
- **개발**: `localhost:5001` (Flask), `localhost:3000` (Rails)

---

## 🎯 현재 완성도

### ✅ **완료된 영역**
- Flutter 앱: UI/UX 100% + 기본기능 100%
- 인증시스템: JWT 토큰 기반 완전 구현
- 데이터베이스: MySQL 연동 및 관리 완료
- Rails 대시보드: Rails 8.0 + Python API 연동 완전 구현
- 권한 시스템: 레벨별 접근 제어 완료
- 검사신청: 3단계 워크플로우 완료

### 📊 **시스템 상태**
- **Flutter 앱**: Production Ready
- **Flask API**: 정상 작동 (포트 5001)
- **Rails Dashboard**: 정상 작동 (포트 3000)
- **MySQL DB**: 8개 테이블, 373개 데이터

---

*📅 최종 업데이트: 2025-07-20*  
*🎯 상태: 2개 프로젝트 모두 핵심 기능 완성*
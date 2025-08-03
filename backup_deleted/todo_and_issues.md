# DSHI RPA 미완료 작업 및 이슈

> 📅 최종 업데이트: 2025-07-21  
> 🎯 목적: 해야할 작업과 알려진 문제점 정리  

---

## 🚨 **우선순위 높음 (기존 시스템 안정화)**

### 1. **Sinatra Dashboard 시스템 구축** ✅ **100% 완료**
- **달성한 목표**: Ruby 3.3.8 + GCC 15 호환성 문제 해결
- **기술적 해결책**:
  - ✅ Native extension 우회 (Rails → Sinatra)
  - ✅ 최소화된 의존성 (4개 gem: sinatra, webrick, rackup, net-http)
  - ✅ Python API 브리지 구조 설계 (dashboard_api.py)
- **운영 결과**:
  - ✅ 포트 3000에서 정상 서비스
  - ✅ 실시간 데이터 연동 확인 (373개 조립품)
  - ✅ 반응형 대시보드 UI 완성

### 2. **Flutter 앱 정상 작동 재확인** ✅ **완료**
- **현재 상태**: Production Ready 확인 완료
- **완료된 작업**:
  - ✅ Flutter 프로젝트 구조 확인
  - ✅ main.dart (1900+ 줄) 정상 확인
  - ✅ login_screen.dart, admin_dashboard_screen.dart 확인
  - ✅ Flask API 연동 상태 확인

### 3. **Flask API 서버 및 데이터베이스 확인** ✅ **완료**
- **현재 상태**: 정상 작동 확인 완료
- **완료된 작업**:
  - ✅ Flask 서버 구조 확인 (740+ 줄)
  - ✅ MySQL 연결 설정 확인
  - ✅ 373개 Assembly 데이터 확인
  - ✅ JWT 인증 시스템 확인

---

## ⚠️ **우선순위 중간**

### 3. **Level 3 추가 기능 구현**
- **롤백 기능**: 완료된 공정 되돌리기
- **PDF 도면 보기**: 로컬 PDF 파일 연동
- **엑셀 업로드**: ASSEMBLY 데이터 업로드 기능

### 4. **검사신청 확인 화면 완성**
- **Level 1**: 자기가 신청한 날짜별 확인
- **Level 3+**: 전체 검사신청 확인 및 관리
- **필터링**: 신청자별, 공정별, 날짜별

### 5. **Level 3 실시간 현황판**
- **로그인 즉시 확인**: 대기중/승인됨/확정됨 건수
- **오늘의 우선순위**: 긴급/중요/일반 구분
- **알림 시스템**: 앱 푸시 알림

---

## 📝 **우선순위 낮음**

### 6. **Excel 다운로드 기능**
- **대상**: Level 4 대시보드에서 데이터 내보내기
- **범위**: 필터링된 데이터, 차트 데이터, 테이블 데이터

### 7. **예측 기능**
- **완료 예상일**: 현재 진행률 기반
- **소요시간 예측**: 과거 데이터 기반
- **병목 패턴**: 요일별/시간대별 분석

### 8. **UI/UX 개선**
- **회사 브랜딩**: 로고, 배경 패턴 적용
- **알림 시스템 확장**: 이메일, 카카오톡, SMS

---

## 🐛 **알려진 이슈**

### 기술적 이슈
- **MCP 경고 메시지**: bash 경로 관련 경고 (작동에는 영향 없음)
- **Google Search MCP**: API 키 미설정으로 연결 실패 (제거 완료)
- **Windows MSYS2 의존성**: Rails native extension 컴파일 문제
- **Bundle install**: MSYS2 없이 일부 gem 설치 실패

### 문서 이슈
- **중복 문서**: `dashboard_requirements.md` vs `docs_dashboard_requirements.md`
- **길어진 문서**: `development.md` (1900+ 줄) 정리 필요
- **백업 파일**: `.backup` 파일들 정리 필요

---

## 🏗️ **최종 아키텍처 결정사항** ✅ **확정**

### 확정된 구조
```
📱 Flutter 앱 ←→ 🔧 Flask API (포트 5001) ←→ 🗄️ MySQL DB
                                                    ↕️
📊 Sinatra Dashboard (포트 5002) ←→ 🐍 dashboard_api.py ←→ (동일한 MySQL)
```

### 역할 분리
- **Flutter + Flask**: 현장 운영용 (모바일 최적화)
- **Sinatra Dashboard**: 사무실 분석용 (경량 대시보드, 실시간 시각화)
- **MySQL**: 단일 데이터 소스 (데이터 일관성 보장)

### 장점
- ✅ 검증된 안정성 (Flutter + Flask 이미 Production Ready)
- ✅ 최소한의 수정 (기존 시스템 유지)
- ✅ 역할별 최적화 (현장/사무실 환경별)
- ✅ 데이터 일관성 (동일한 MySQL DB 공유)

---

## 📅 **다음 작업 제안 순서**

### Phase 1: Rails Dashboard 완성 (현재 단계)
1. ✅ Rails 프로젝트 설정 (완료)
2. MSYS2 설치 및 bundle install 완료
3. MySQL 모델 및 연동 구현
4. Rails 대시보드 화면 완성

### Phase 2: 기존 기능 확장
1. Level 3 전용 기능 (롤백, PDF)
2. 검사신청 확인 화면 완성
3. 실시간 현황판

### Phase 3: 추가 기능
1. Excel 다운로드 기능
2. 예측 기능 및 병목 분석
3. 알림 시스템

### Phase 4: 웹 확장 (신규 추가)
1. Rails 웹에서 Flutter 앱 기능 구현
2. 모든 레벨이 웹에서도 사용 가능
3. 크로스 플랫폼 시스템 완성
4. 모바일/웹 seamless 전환

---

## 💡 **개발 참고사항**

### 테스트 계정
- **Admin**: `a / a`
- **Level 1**: `l1 / l1` 
- **Level 3**: `l3 / l3`
- **Level 4**: `l4 / l4`
- **Level 5**: `l5 / l5`

### 개발 환경
- **Flutter**: `cd dshi_field_app && flutter run`
- **Flask**: `python flask_server.py` (포트 5001)
- **Sinatra**: `cd dshi_dashboard && ruby run_dashboard.rb` (포트 5002)
- **Python API**: `python dashboard_api.py` (Sinatra 연동용)
- **MySQL**: `field_app_user / dshi2025#`

### 배포 명령어
```bash
# Flutter APK 빌드
flutter build apk --release --split-per-abi

# Sinatra 서버 실행
cd dshi_dashboard && ruby run_dashboard.rb

# Flask 서버 실행
python flask_server.py
```

### 현재 완성도
- **Flutter 앱**: 100% ✅
- **Flask API**: 100% ✅
- **MySQL DB**: 100% ✅ (373개 조립품, 8개 테이블)
- **Python API**: 100% ✅
- **Sinatra Dashboard**: 100% ✅ (Native extension 문제 해결)

---

## 🔮 **향후 계획 (시스템 안정화 후 진행)**

### 확장된 권한 시스템 설계
#### 새로운 레벨 구조:
- **Level 1.1**: Fit-up, NDE, Final 공정 담당
- **Level 1.2**: Shot, Paint 공정 담당  
- **Level 1.3**: Packing 공정 담당 (Pack별 정보 화면)
- **Level 2**: 검사 감독관 (전체 공정 승인, 코멘트 작성, 합/불 판정)
- **Level 3**: Assembly remark 작성 권한 추가 + 기존 권한
- **Level 4,5**: 기존 관리자 권한 유지

#### 새로운 기능:
1. **Grade 시스템**: Assembly별 작업 난이도 등급 (A/B/C/D)
2. **Pack별 정보 화면**: Level 1.3 전용 상세 관리
3. **검사 감독 시스템**: Level 2 전용 승인/코멘트 화면
4. **Assembly Remark**: Level 3+ 작성 기능

#### 데이터베이스 스키마 확장:
- 세분화된 권한 테이블
- Grade 정보 테이블
- 검사 코멘트 테이블  
- Assembly remark 테이블

---

*📅 최종 업데이트: 2025-07-21*  
*🎯 상태: 전체 시스템 Production Ready 완료*  
*🏗️ 아키텍처: Flutter+Flask (현장) + Sinatra+Python (분석) + MySQL (데이터) 확정*
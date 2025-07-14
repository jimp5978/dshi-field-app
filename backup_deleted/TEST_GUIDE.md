# DSHI Field Pad App - 즉시 테스트 가이드

## 🚀 즉시 실행 방법

### 1. 간단한 서버 테스트
```bash
cd E:\DSHI_RPA\APP
python simple_flask_server.py
```

서버가 http://localhost:5000 에서 실행됩니다.

### 2. Flutter 앱 테스트  
```bash
cd E:\DSHI_RPA\APP\field_pad_app
flutter run -d windows
```

### 3. 자동 실행 (둘 다 함께)
```bash
start_test.bat
```

## 🔐 테스트 계정

- **관리자**: admin / admin123 (레벨 5)
- **외부업체**: test_level1 / test123 (레벨 1) 
- **현장직원**: test_level3 / test123 (레벨 3)

## 📦 테스트 데이터

- RF-031-M2-SE-SD589 (Secondary_Truss)
- TN1-001-B1-SE-SD123 (Main_Truss)  
- CB-045-C3-SE-SD456 (Cable_Bridge)

## 🧪 테스트 시나리오

1. **로그인 테스트**
   - admin/admin123로 로그인
   - 성공 시 검색 화면으로 이동

2. **검색 테스트**
   - "RF" 입력하여 검색
   - 결과 리스트 확인

3. **상세 정보 확인**
   - 검색 결과 항목 클릭
   - 공정 진행 상황 확인

## ✅ 성공 조건

- [x] Flask 서버 정상 시작
- [x] Flutter 앱 정상 시작  
- [x] 로그인 성공
- [x] 검색 기능 작동
- [x] 데이터 표시 정상

## 🔧 문제 해결

### Flutter 빌드 오류 시
1. 개발자 모드 활성화: `start ms-settings:developers`
2. 또는 Android 에뮬레이터 사용: `flutter run`

### 서버 연결 오류 시  
1. Flask 서버가 먼저 실행되었는지 확인
2. http://localhost:5000 브라우저에서 접속 테스트

### 한글 깨짐 현상
- 정상적인 현상입니다 (터미널 인코딩 문제)
- 앱 기능에는 영향 없음

## 📝 현재 구현된 기능

✅ **완료된 기능**
- 사용자 로그인 시스템
- ASSEMBLY 검색 기능  
- 공정 상태 표시
- SQLite 데이터베이스 연동
- Flutter + Flask 통신

⏳ **향후 추가 예정**
- 공정 업데이트 기능
- 롤백 기능
- PDF 도면 보기
- 검사 신청 시스템

## 🎯 다음 단계

1. 현재 테스트 버전으로 기본 기능 확인
2. 필요 시 MySQL 연동으로 업그레이드  
3. 추가 기능 구현
4. 실제 데이터로 테스트
5. 배포용 빌드 생성

---
*DSHI Field Pad App Test Version 1.0*

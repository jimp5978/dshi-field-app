# 🏠 집에서 DSHI Field Pad 개발환경 구축 가이드

이 가이드는 사무실에서 개발한 DSHI Field Pad 프로젝트를 집에서도 동일한 환경으로 작업할 수 있도록 설정하는 방법을 단계별로 설명합니다.

## 📋 목차
1. [Git 설정 및 코드 다운로드](#1-git-설정-및-코드-다운로드)
2. [Docker Desktop 설치](#2-docker-desktop-설치)
3. [프로젝트 실행](#3-프로젝트-실행)
4. [개발 작업 진행](#4-개발-작업-진행)
5. [문제 해결](#5-문제-해결)

---

## 1. Git 설정 및 코드 다운로드

### 1.1 Git 설치 확인
```bash
# Git 버전 확인
git --version
```

### 1.2 Git 계정 설정 (최초 1회만)
```bash
# 사용자 이름 설정
git config --global user.name "본인이름"

# 이메일 설정
git config --global user.email "본인이메일@example.com"

# 한글 파일명 문제 해결
git config --global core.quotePath false
```

### 1.3 프로젝트 클론 (최초 1회만)
```bash
# 작업할 폴더로 이동 (예: C:\Projects)
cd C:\Projects

# 저장소 클론 (저장소 URL은 실제 주소로 변경)
git clone https://github.com/사용자명/DSHI_RPA.git

# 프로젝트 폴더로 이동
cd DSHI_RPA\APP
```

### 1.4 기존 코드 업데이트 (2회차부터)
```bash
# 프로젝트 폴더로 이동
cd C:\Projects\DSHI_RPA\APP

# 최신 코드 받기
git pull origin master
```

---

## 2. Docker Desktop 설치

### 2.1 시스템 요구사항 확인
- **운영체제**: Windows 10/11 (64비트)
- **메모리**: 최소 4GB RAM (8GB 권장)
- **가상화**: BIOS에서 가상화 기능 활성화 필요

### 2.2 Docker Desktop 다운로드 및 설치

#### 방법 1: 공식 웹사이트에서 다운로드
1. https://www.docker.com/products/docker-desktop 접속
2. "Download for Windows" 버튼 클릭
3. Docker Desktop Installer.exe 다운로드

#### 방법 2: 직접 다운로드 링크
```
https://desktop.docker.com/win/main/amd64/Docker%20Desktop%20Installer.exe
```

### 2.3 설치 과정
1. **Docker Desktop Installer.exe 실행**
2. **설치 옵션 선택**:
   - ✅ "Use WSL 2 instead of Hyper-V" (권장)
   - ✅ "Add shortcut to desktop"
3. **설치 진행** (약 5-10분 소요)
4. **재부팅** (설치 완료 후 필수)

### 2.4 WSL 2 설정 (필요한 경우)
재부팅 후 Docker Desktop 실행 시 WSL 2 관련 오류가 발생하면:

1. **Windows PowerShell을 관리자 권한으로 실행**
2. **WSL 2 활성화**:
```powershell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```
3. **재부팅**
4. **Linux 커널 업데이트 패키지 설치**:
   - https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi 다운로드 및 설치

### 2.5 Docker 설치 확인
```bash
# Docker 버전 확인
docker --version

# Docker Compose 버전 확인
docker compose version

# Docker 상태 확인
docker info
```

**정상 출력 예시:**
```
Docker version 24.0.7, build afdd53b
Docker Compose version v2.21.0
```

---

## 3. 프로젝트 실행

### 3.1 프로젝트 폴더로 이동
```bash
cd C:\Projects\DSHI_RPA\APP
```

### 3.2 Docker 환경 실행
```bash
# 최초 실행 (이미지 빌드 포함)
docker compose up --build -d

# 실행 로그 확인
docker compose logs -f
```

### 3.3 서비스 상태 확인
```bash
# 컨테이너 상태 확인
docker compose ps
```

**정상 상태 출력 예시:**
```
NAME                IMAGE               STATUS
dshi_flask_api      app-flask-api       Up 2 minutes (healthy)
dshi_mysql          mysql:8.0           Up 3 minutes (healthy)  
dshi_web_app        app-web             Up 1 minute (healthy)
```

### 3.4 웹 애플리케이션 접속
브라우저에서 다음 주소로 접속:
- **메인 애플리케이션**: http://localhost:5007
- **Flask API**: http://localhost:5001

### 3.5 로그인 계정
- **관리자**: `admin` / `admin123` (Level 3)
- **검사원**: `inspector1` / `admin123` (Level 2)
- **일반사용자**: `user1` / `admin123` (Level 1)

---

## 4. 개발 작업 진행

### 4.1 코드 수정 작업
코드 수정 후 변경사항 반영:

```bash
# 특정 서비스만 재시작
docker compose restart web
docker compose restart flask-api

# 코드 변경 후 이미지 재빌드
docker compose build web
docker compose up -d web
```

### 4.2 작업 완료 후 Git 저장
```bash
# 변경된 파일 확인
git status

# 변경사항 스테이징
git add .

# 커밋
git commit -m "작업 내용 설명"

# 원격 저장소에 푸시
git push origin master
```

### 4.3 작업 종료
```bash
# Docker 컨테이너 중지
docker compose down

# 완전 정리 (볼륨 포함)
docker compose down -v
```

---

## 5. 문제 해결

### 5.1 Docker 관련 문제

#### 문제: "docker: command not found"
**해결방법:**
1. Docker Desktop이 실행 중인지 확인
2. 시스템 재부팅
3. 환경변수 PATH에 Docker 경로 추가

#### 문제: "WSL 2 installation is incomplete"
**해결방법:**
1. Windows 기능에서 "Linux용 Windows 하위 시스템" 활성화
2. WSL 2 Linux 커널 업데이트
3. 재부팅 후 Docker Desktop 재시작

#### 문제: 포트 충돌 (Port already in use)
**해결방법:**
```bash
# 사용 중인 포트 확인
netstat -ano | findstr :5007
netstat -ano | findstr :5001

# 해당 프로세스 종료 또는 Docker 포트 변경
```

### 5.2 Git 관련 문제

#### 문제: "fatal: not a git repository"
**해결방법:**
```bash
# 올바른 프로젝트 폴더인지 확인
pwd
ls -la

# .git 폴더가 있는 디렉토리로 이동
cd C:\Projects\DSHI_RPA\APP
```

#### 문제: 한글 파일명 깨짐
**해결방법:**
```bash
git config --global core.quotePath false
git config --global core.precomposeunicode true
```

### 5.3 웹 애플리케이션 문제

#### 문제: 웹페이지가 로딩되지 않음
**해결순서:**
1. Docker 컨테이너 상태 확인: `docker compose ps`
2. 로그 확인: `docker compose logs web`
3. 네트워크 확인: `docker compose logs flask-api`
4. 재시작: `docker compose restart`

#### 문제: 데이터베이스 연결 오류
**해결방법:**
```bash
# MySQL 컨테이너 로그 확인
docker compose logs mysql

# 데이터베이스 초기화
docker compose down -v
docker compose up --build -d
```

---

## 6. 주요 명령어 정리

### Git 명령어
```bash
git pull origin master          # 최신 코드 받기
git status                      # 변경사항 확인
git add .                       # 모든 변경사항 스테이징
git commit -m "메시지"          # 커밋
git push origin master          # 원격 저장소에 푸시
git log --oneline -5            # 최근 커밋 확인
```

### Docker 명령어
```bash
docker compose up -d            # 백그라운드 실행
docker compose down             # 중지
docker compose ps               # 상태 확인
docker compose logs -f          # 로그 실시간 확인
docker compose restart web      # 특정 서비스 재시작
docker compose build            # 이미지 재빌드
```

---

## 7. 체크리스트

작업 시작 전 확인사항:
- [ ] Git 설치 및 계정 설정 완료
- [ ] Docker Desktop 설치 및 실행 확인
- [ ] 최신 코드 다운로드 (`git pull`)
- [ ] Docker 환경 실행 (`docker compose up -d`)
- [ ] 웹 애플리케이션 접속 확인 (http://localhost:5007)

작업 완료 후 확인사항:
- [ ] 변경사항 Git 커밋 및 푸시
- [ ] Docker 컨테이너 정리 (`docker compose down`)

---

## 📞 추가 도움

문제가 계속 발생하면:
1. **Docker 로그 확인**: `docker compose logs`
2. **시스템 재부팅** 후 재시도
3. **Docker Desktop 재설치**
4. **프로젝트 폴더 완전 삭제 후 다시 클론**

---
*이 가이드로 집에서도 사무실과 동일한 개발환경을 구축할 수 있습니다! 🏠💻*
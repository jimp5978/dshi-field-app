# Flask Server 경량화 및 성능 최적화 계획서

> 📅 **작성일**: 2025-08-04  
> 🎯 **목표**: 2,166줄 flask_server.py 경량화 + 데이터 로딩 성능 개선  
> 🛡️ **원칙**: 정상 작동 100% 보장, 단계적 안전한 진행  

---

## 🚨 **현재 문제점 분석**

### 파일 크기 문제
- **현재 상태**: `flask_server.py` 2,166줄 (단일 파일)
- **API 엔드포인트**: 26개
- **함수 개수**: 37개
- **관리 어려움**: 특정 기능 수정 시 전체 파일 검토 필요

### 성능 문제 (핵심 이슈)
- **대시보드 API**: 한 번 호출시 **18개 개별 쿼리** 실행
  - 전체 통계 조회 (1개)
  - 8단계 공정별 쿼리 (8개)
  - 상태별 분포 쿼리 (3개)
  - 업체별 분포 쿼리 (1개)
  - 월별 진행률 쿼리 (1개)
  - BEAM 아이템 8단계 쿼리 (8개)
  - POST 아이템 8단계 쿼리 (8개)
- **데이터 규모**: 5,758개 조립품 데이터 매번 풀스캔
- **캐시 없음**: 실시간 계산으로 인한 중복 연산
- **동적 SQL**: f-string 사용으로 인한 추가 오버헤드

---

## 📋 **3단계 점진적 최적화 계획**

### **Phase 1: 대시보드 성능 즉시 개선** ⚡ (최우선)
**목표**: 18개 쿼리 → 2-3개 통합 쿼리로 성능 극대화

#### 1.1 SQL 쿼리 최적화
```sql
-- 현재: 18개 개별 쿼리
SELECT COUNT(*) FROM arup_ecs...  -- 전체 통계
SELECT SUM(weight_net) FROM arup_ecs WHERE fit_up_date...  -- FIT_UP
SELECT SUM(weight_net) FROM arup_ecs WHERE final_date...   -- FINAL
... (16개 더)

-- 개선: 단일 복합 쿼리
WITH process_stats AS (
  SELECT 
    COUNT(*) as total_assemblies,
    SUM(weight_net) as total_weight,
    SUM(CASE WHEN fit_up_date IS NOT NULL AND fit_up_date != '1900-01-01' THEN weight_net ELSE 0 END) as fit_up_weight,
    SUM(CASE WHEN final_date IS NOT NULL AND final_date != '1900-01-01' THEN weight_net ELSE 0 END) as final_weight,
    -- ... 모든 공정 한 번에 계산
  FROM arup_ecs WHERE weight_net IS NOT NULL
)
SELECT * FROM process_stats;
```

#### 1.2 메모리 캐시 도입
- **Flask-Caching** 라이브러리 추가
- **캐시 TTL**: 5분 (300초)
- **캐시 키**: `dashboard_data_{timestamp}`
- **캐시 무효화**: 수동 갱신 API 추가

#### 1.3 데이터베이스 인덱스 최적화
```sql
-- 확인할 인덱스들
SHOW INDEX FROM arup_ecs;

-- 필요시 추가할 복합 인덱스
CREATE INDEX idx_process_dates ON arup_ecs(fit_up_date, final_date, arup_final_date, galv_date);
CREATE INDEX idx_item_weight ON arup_ecs(item, weight_net);
CREATE INDEX idx_company_weight ON arup_ecs(company, weight_net);
```

#### **Phase 1 예상 효과**
- 쿼리 수: **18개 → 2-3개** (85% 감소)
- 대시보드 로딩 시간: **70-80% 단축**
- 서버 부하: **대폭 감소**

---

### **Phase 2: 핵심 모듈 분리** 🏗️ (안정성 우선)
**목표**: 가장 무거운 부분만 선별적 분리

#### 2.1 새로운 파일 구조 (1단계)
```
E:\DSHI_RPA\APP\
├── flask_server.py (메인 - 1,500줄 목표)
├── api/
│   ├── __init__.py
│   └── dashboard.py (대시보드 전용 - 200줄)
├── utils/
│   ├── __init__.py
│   ├── database.py (DB 연결, 공통 쿼리 - 150줄)
│   ├── auth.py (JWT, 데코레이터 - 100줄)
│   └── cache.py (캐시 관리 - 50줄)
└── requirements.txt (Flask-Caching 추가)
```

#### 2.2 Blueprint 패턴 도입
```python
# api/dashboard.py
from flask import Blueprint
from utils.database import get_db_connection
from utils.cache import cached

dashboard_bp = Blueprint('dashboard', __name__)

@dashboard_bp.route('/api/dashboard-data', methods=['GET'])
@token_required
@cached(timeout=300)  # 5분 캐시
def get_dashboard_data(current_user):
    # 최적화된 대시보드 로직
    pass

# flask_server.py에서 등록
from api.dashboard import dashboard_bp
app.register_blueprint(dashboard_bp)
```

#### 2.3 공통 유틸리티 분리
- **database.py**: DB 연결, 공통 쿼리 함수
- **auth.py**: JWT 토큰, `@token_required` 데코레이터
- **cache.py**: 캐시 설정 및 관리

#### **Phase 2 예상 효과**
- 메인 파일: **2,166줄 → 1,500줄** (31% 감소)
- 기능별 독립 수정 가능
- 대시보드 성능 유지

---

### **Phase 3: 전체 모듈화 완성** 📦 (관리성 극대화)
**목표**: 기능별 완전 분리로 유지보수성 극대화

#### 3.1 최종 파일 구조
```
E:\DSHI_RPA\APP\
├── flask_server.py (메인 - 200줄 이하) ⭐
├── api/
│   ├── __init__.py
│   ├── auth.py (로그인, 토큰 - 300줄)
│   ├── assembly.py (조립품 검색 - 400줄)
│   ├── inspection.py (검사신청 관리 - 500줄)
│   ├── admin.py (사용자 관리 - 300줄)
│   ├── dashboard.py (대시보드 - 200줄)
│   └── excel.py (엑셀 처리 - 300줄)
├── utils/
│   ├── __init__.py
│   ├── database.py (DB 관리 - 150줄)
│   ├── auth.py (인증 유틸 - 100줄)
│   ├── process.py (공정 계산 - 100줄)
│   └── cache.py (캐시 관리 - 50줄)
├── config/
│   └── settings.py (환경 설정 통합)
└── requirements.txt (업데이트됨)
```

#### 3.2 기능별 Blueprint 완전 분리
- **auth.py**: `/api/login` 엔드포인트
- **assembly.py**: `/api/assemblies/*` 엔드포인트들
- **inspection.py**: `/api/inspection-*` 엔드포인트들
- **admin.py**: `/api/admin/*` 엔드포인트들
- **excel.py**: `/api/upload-*` 엔드포인트들

#### 3.3 메인 파일 최종 모습
```python
# flask_server.py (최종 - 200줄 이하)
from flask import Flask
from flask_cors import CORS
from config.settings import get_config
from utils.cache import init_cache

# Blueprint 임포트
from api.auth import auth_bp
from api.assembly import assembly_bp
from api.inspection import inspection_bp
from api.admin import admin_bp
from api.dashboard import dashboard_bp
from api.excel import excel_bp

app = Flask(__name__)
CORS(app)
app.config.update(get_config())

# 캐시 초기화
init_cache(app)

# Blueprint 등록
app.register_blueprint(auth_bp)
app.register_blueprint(assembly_bp)
app.register_blueprint(inspection_bp)
app.register_blueprint(admin_bp)
app.register_blueprint(dashboard_bp)
app.register_blueprint(excel_bp)

@app.route('/')
def home():
    return "DSHI Field App API Server"

@app.route('/api/health')
def health_check():
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5001, debug=False)
```

#### **Phase 3 예상 효과**
- 메인 파일: **2,166줄 → 200줄 이하** (91% 감소)
- 각 모듈 독립성 완전 확보
- 새 기능 추가시 해당 모듈만 수정
- 팀 개발시 충돌 최소화

---

## 🔄 **각 단계별 테스트 프로세스**

### 테스트 체크리스트
```
□ 1. 코드 수정 완료
□ 2. 기존 flask_server.py 백업 생성
□ 3. 서버 재시작 테스트
□ 4. Sinatra 웹앱 연동 확인
  □ 4.1 로그인 기능
  □ 4.2 조립품 검색
  □ 4.3 저장 리스트 관리
  □ 4.4 검사신청 기능
  □ 4.5 검사신청 관리
  □ 4.6 대시보드 로딩
  □ 4.7 엑셀 업로드
□ 5. 성능 측정 (대시보드 로딩 시간)
□ 6. 결과 피드백 및 다음 단계 진행
```

### 성능 측정 방법
```bash
# 대시보드 API 응답 시간 측정
curl -w "Total time: %{time_total}s\n" \
     -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     -X GET http://localhost:5001/api/dashboard-data
```

---

## ⏱️ **예상 효과 요약**

| Phase | 메인 파일 크기 | 대시보드 성능 | 관리성 | 안정성 |
|-------|---------------|---------------|--------|--------|
| 현재 | 2,166줄 | 느림 (18 쿼리) | 어려움 | 안정 |
| Phase 1 | 2,166줄 | **빠름** (2-3 쿼리) | 어려움 | 안정 |
| Phase 2 | ~1,500줄 | 빠름 | 보통 | 안정 |
| Phase 3 | **~200줄** | 빠름 | **매우 좋음** | 안정 |

### 구체적 개선 효과
- **대시보드 로딩**: 70-80% 시간 단축
- **메인 파일 크기**: 91% 감소 (2,166 → 200줄)
- **기능 독립성**: 모듈별 독립 수정 가능
- **확장성**: 새 기능 추가시 해당 모듈만 작업

---

## 🛡️ **안전장치 및 롤백 계획**

### 백업 전략
```bash
# 각 단계 전 백업
cp flask_server.py flask_server_backup_phase1.py
cp flask_server.py flask_server_backup_phase2.py
cp flask_server.py flask_server_backup_phase3.py
```

### 롤백 절차
```bash
# 문제 발생시 즉시 롤백
cp flask_server_backup_phaseX.py flask_server.py
# 서버 재시작으로 즉시 복구
```

### API 호환성 보장
- **모든 URL 동일 유지**: `/api/*` 엔드포인트 변경 없음
- **응답 형식 동일**: JSON 구조 100% 호환
- **Sinatra 코드 수정 불필요**: 기존 `FlaskClient.rb` 그대로 사용

### 단계별 검증점
1. **Phase 1**: 대시보드 성능 측정 후 다음 단계
2. **Phase 2**: 전체 기능 테스트 후 다음 단계  
3. **Phase 3**: 최종 통합 테스트 완료

---

## 🚀 **시작 준비**

### 필요 라이브러리
```bash
pip install Flask-Caching
```

### 첫 번째 작업
1. **Phase 1** 대시보드 성능 최적화부터 시작
2. SQL 쿼리 통합 작업
3. 성능 측정 및 효과 확인

**준비되면 언제든지 Phase 1부터 시작하겠습니다!** 🎯

---

*📅 **최종 업데이트**: 2025-08-04*  
*🎯 **상태**: 계획 수립 완료, 실행 대기중*  
*⚡ **우선순위**: Phase 1 대시보드 성능 최적화*  
*🛡️ **안전성**: 단계별 백업 및 롤백 체계 완비*
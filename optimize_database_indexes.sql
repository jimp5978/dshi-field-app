-- 🚀 Phase 3: 데이터베이스 인덱스 최적화
-- 성능 향상을 위한 인덱스 추가

-- 1. 저장된 리스트 조회 최적화 (user_id + updated_at)
CREATE INDEX IF NOT EXISTS idx_user_saved_lists_user_updated 
ON user_saved_lists(user_id, updated_at DESC);

-- 2. Assembly 검색 최적화 (assembly_code 끝 3자리)
CREATE INDEX IF NOT EXISTS idx_arup_ecs_assembly_code_suffix 
ON arup_ecs(assembly_code);

-- 3. Assembly 검색 최적화 (item 필드)
CREATE INDEX IF NOT EXISTS idx_arup_ecs_item 
ON arup_ecs(item);

-- 4. 복합 검색 최적화 (assembly_code + item)
CREATE INDEX IF NOT EXISTS idx_arup_ecs_search 
ON arup_ecs(assembly_code, item);

-- 5. 검사신청 조회 최적화 (사용자별 + 날짜순)
CREATE INDEX IF NOT EXISTS idx_inspection_requests_user_date 
ON inspection_requests(requested_by_user_id, created_at DESC);

-- 6. 검사신청 상태별 조회 최적화
CREATE INDEX IF NOT EXISTS idx_inspection_requests_status 
ON inspection_requests(status, created_at DESC);

-- 인덱스 생성 완료 확인
SHOW INDEX FROM user_saved_lists;
SHOW INDEX FROM arup_ecs;
SHOW INDEX FROM inspection_requests;
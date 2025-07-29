-- ARUP_ECS 프로젝트 테이블 생성 스크립트
-- 날짜: 2025-07-21
-- 기존 assembly_items 테이블을 대체하는 arup_ecs 테이블

-- 기존 assembly_items 테이블 삭제
DROP TABLE IF EXISTS assembly_items;

-- arup_ecs 테이블 생성 (Excel total_arup 시트 구조 기반)
CREATE TABLE arup_ecs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    assembly_code VARCHAR(100) NOT NULL UNIQUE,  -- ASSEMBLY 컬럼
    company VARCHAR(100),                         -- COMPANY 컬럼
    zone VARCHAR(50),                            -- ZONE 컬럼
    item VARCHAR(100),                           -- ITEM 컬럼
    weight_net DECIMAL(10,2),                    -- WEIGHT_(NET) 컬럼
    
    -- 8단계 공정 날짜 컬럼들
    fit_up_date DATE,                            -- FIT-UP
    final_date DATE,                             -- FINAL
    arup_final_date DATE,                        -- ARUP_FINAL
    galv_date DATE,                              -- GALV
    arup_galv_date DATE,                         -- ARUP_GALV
    shot_date DATE,                              -- SHOT
    paint_date DATE,                             -- PAINT
    arup_paint_date DATE,                        -- ARUP_PAINT
    
    remark TEXT,                                 -- REMARK 컬럼 (사용자 메모)
    
    -- 시스템 관리 컬럼
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- 인덱스
    INDEX idx_assembly_code (assembly_code),
    INDEX idx_zone (zone),
    INDEX idx_company (company),
    INDEX idx_item (item)
);

-- 테이블 생성 확인
DESCRIBE arup_ecs;
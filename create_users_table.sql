-- DSHI Field Pad 사용자 관리 테이블 생성
-- 실행 방법: MySQL에서 이 파일을 실행하세요

USE field_app_db;

-- 기존 테이블이 있으면 삭제 (주의: 데이터 손실 발생)
-- DROP TABLE IF EXISTS users;

-- 사용자 테이블 생성
CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(64) NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    permission_level INT NOT NULL DEFAULT 1,
    company VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    
    -- 인덱스 추가
    INDEX idx_username (username),
    INDEX idx_permission_level (permission_level),
    INDEX idx_is_active (is_active)
);

-- 초기 사용자 데이터 삽입
INSERT INTO users (username, password_hash, full_name, permission_level, company) VALUES
('admin', 'ca978112ca1bbdcafac231b39a23dc4da786eff8147c4e72b9807785afee48bb', 'Admin', 5, 'DSHI'),
('seojin', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', '서진', 1, '서진'),
('sookang', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', '수강', 1, '수강'),
('gyeongin', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', '경인', 1, '경인'),
('dshi_hy', '03ac674216f3e15c761ee1a5e255f067953623c8b388b4459e13f978d7c846f4', 'dshi_hy', 3, 'DSHI');

-- 테이블 확인
SELECT * FROM users;

-- 권한별 사용자 수 확인
SELECT permission_level, COUNT(*) as user_count 
FROM users 
WHERE is_active = TRUE 
GROUP BY permission_level;
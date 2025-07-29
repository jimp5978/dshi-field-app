-- DSHI Field Pad 데이터베이스 초기화 스크립트

-- 사용자 테이블 생성
CREATE TABLE IF NOT EXISTS users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    permission_level INT DEFAULT 1,
    full_name VARCHAR(100),
    department VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 검사신청 테이블 생성
CREATE TABLE IF NOT EXISTS inspection_requests (
    id INT PRIMARY KEY AUTO_INCREMENT,
    assembly_code VARCHAR(100) NOT NULL,
    inspection_type VARCHAR(50) NOT NULL,
    requester VARCHAR(100) NOT NULL,
    request_date DATE NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_assembly_code (assembly_code),
    INDEX idx_status (status),
    INDEX idx_request_date (request_date)
);

-- 사용자별 저장된 리스트 테이블 생성
CREATE TABLE IF NOT EXISTS user_saved_lists (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    assembly_code VARCHAR(100) NOT NULL,
    assembly_data JSON NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_assembly (user_id, assembly_code),
    INDEX idx_user_id (user_id),
    INDEX idx_assembly_code (assembly_code)
);

-- 기본 관리자 계정 생성 (비밀번호: admin123)
INSERT IGNORE INTO users (username, password_hash, permission_level, full_name, department) 
VALUES ('admin', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeilvHCy/MS/TTFGy', 3, '시스템 관리자', 'IT');

-- 테스트 사용자 계정들 생성
INSERT IGNORE INTO users (username, password_hash, permission_level, full_name, department) VALUES
('inspector1', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeilvHCy/MS/TTFGy', 2, '검사원1', '품질관리'),
('user1', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeilvHCy/MS/TTFGy', 1, '일반사용자1', '생산'),
('user2', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/LeilvHCy/MS/TTFGy', 1, '일반사용자2', '생산');

-- 샘플 검사신청 데이터
INSERT IGNORE INTO inspection_requests (assembly_code, inspection_type, requester, request_date, status) VALUES
('ASM001', 'FIT_UP', 'user1', '2024-01-15', 'approved'),
('ASM002', 'FINAL', 'user2', '2024-01-16', 'pending'),
('ASM003', 'GALV', 'inspector1', '2024-01-17', 'confirmed');

-- 인덱스 최적화
ANALYZE TABLE users;
ANALYZE TABLE inspection_requests;
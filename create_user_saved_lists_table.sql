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
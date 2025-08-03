-- inspection_requests 테이블에 승인자/확정자 정보 컬럼 추가
-- 실행 방법: mysql -u field_app_user -p field_app_db < add_approval_columns.sql

-- 컬럼 존재 여부 확인 후 추가
SET @sql1 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND column_name = 'approved_by') = 0,
    'ALTER TABLE inspection_requests ADD COLUMN approved_by INT',
    'SELECT "approved_by column already exists"'
));
PREPARE stmt1 FROM @sql1;
EXECUTE stmt1;
DEALLOCATE PREPARE stmt1;

SET @sql2 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND column_name = 'approved_by_name') = 0,
    'ALTER TABLE inspection_requests ADD COLUMN approved_by_name VARCHAR(100)',
    'SELECT "approved_by_name column already exists"'
));
PREPARE stmt2 FROM @sql2;
EXECUTE stmt2;
DEALLOCATE PREPARE stmt2;

SET @sql3 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND column_name = 'approved_date') = 0,
    'ALTER TABLE inspection_requests ADD COLUMN approved_date TIMESTAMP NULL',
    'SELECT "approved_date column already exists"'
));
PREPARE stmt3 FROM @sql3;
EXECUTE stmt3;
DEALLOCATE PREPARE stmt3;

SET @sql4 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND column_name = 'confirmed_by') = 0,
    'ALTER TABLE inspection_requests ADD COLUMN confirmed_by INT',
    'SELECT "confirmed_by column already exists"'
));
PREPARE stmt4 FROM @sql4;
EXECUTE stmt4;
DEALLOCATE PREPARE stmt4;

SET @sql5 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND column_name = 'confirmed_by_name') = 0,
    'ALTER TABLE inspection_requests ADD COLUMN confirmed_by_name VARCHAR(100)',
    'SELECT "confirmed_by_name column already exists"'
));
PREPARE stmt5 FROM @sql5;
EXECUTE stmt5;
DEALLOCATE PREPARE stmt5;

SET @sql6 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.COLUMNS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND column_name = 'confirmed_date') = 0,
    'ALTER TABLE inspection_requests ADD COLUMN confirmed_date TIMESTAMP NULL',
    'SELECT "confirmed_date column already exists"'
));
PREPARE stmt6 FROM @sql6;
EXECUTE stmt6;
DEALLOCATE PREPARE stmt6;

-- 인덱스 추가 (존재하지 않는 경우만)
SET @sql7 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND index_name = 'idx_approved_by') = 0,
    'ALTER TABLE inspection_requests ADD INDEX idx_approved_by (approved_by)',
    'SELECT "idx_approved_by index already exists"'
));
PREPARE stmt7 FROM @sql7;
EXECUTE stmt7;
DEALLOCATE PREPARE stmt7;

SET @sql8 = (SELECT IF(
    (SELECT COUNT(*) FROM information_schema.STATISTICS 
     WHERE table_name = 'inspection_requests' 
     AND table_schema = 'field_app_db' 
     AND index_name = 'idx_confirmed_by') = 0,
    'ALTER TABLE inspection_requests ADD INDEX idx_confirmed_by (confirmed_by)',
    'SELECT "idx_confirmed_by index already exists"'
));
PREPARE stmt8 FROM @sql8;
EXECUTE stmt8;
DEALLOCATE PREPARE stmt8;

-- 외래키 제약조건은 Docker 환경에서 users 테이블과의 의존성 문제로 생략
-- 필요 시 수동으로 추가 가능

SELECT 'Migration completed successfully!' as result;
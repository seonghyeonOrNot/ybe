-- 휴가 관리 시스템 데이터베이스 스키마
-- Database: PostgreSQL (MySQL 호환 가능)

-- ========================================
-- 1. 관리자 테이블
-- ========================================
CREATE TABLE admins (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'ADMIN',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_email (email)
);

-- ========================================
-- 2. 직원 테이블
-- ========================================
CREATE TABLE users (
    id VARCHAR(36) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL UNIQUE,
    department VARCHAR(100),
    position VARCHAR(100),
    is_eligible BOOLEAN DEFAULT true COMMENT '휴가 수동 부여 대상 여부',
    hire_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_email (email),
    INDEX idx_department (department),
    INDEX idx_is_eligible (is_eligible)
);

-- ========================================
-- 3. 휴가 잔액 테이블
-- ========================================
CREATE TABLE vacation_balances (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    year INT NOT NULL,
    total_days DECIMAL(5,2) DEFAULT 0.00 COMMENT '총 휴가 일수',
    used_days DECIMAL(5,2) DEFAULT 0.00 COMMENT '사용한 휴가 일수',
    remaining_days DECIMAL(5,2) GENERATED ALWAYS AS (total_days - used_days) STORED COMMENT '잔여 휴가 일수',
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    UNIQUE KEY unique_user_year (user_id, year),
    INDEX idx_user_id (user_id),
    INDEX idx_year (year)
);

-- ========================================
-- 4. 휴가 부여 기록 테이블
-- ========================================
CREATE TABLE vacation_assignments (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    admin_id VARCHAR(36) NOT NULL,
    days_granted DECIMAL(5,2) NOT NULL COMMENT '부여한 휴가 일수',
    reason TEXT NOT NULL COMMENT '부여 사유',
    valid_from DATE COMMENT '유효 시작일',
    valid_until DATE COMMENT '유효 종료일',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE RESTRICT,
    INDEX idx_user_id (user_id),
    INDEX idx_admin_id (admin_id),
    INDEX idx_created_at (created_at),

    CONSTRAINT chk_days_granted_positive CHECK (days_granted > 0),
    CONSTRAINT chk_valid_dates CHECK (valid_until IS NULL OR valid_until >= valid_from)
);

-- ========================================
-- 5. 감사 로그 테이블 (선택적)
-- ========================================
CREATE TABLE audit_logs (
    id VARCHAR(36) PRIMARY KEY,
    admin_id VARCHAR(36) NOT NULL,
    action VARCHAR(100) NOT NULL COMMENT '액션 유형 (ASSIGN_VACATION, VIEW_LIST 등)',
    target_user_id VARCHAR(36),
    details JSON COMMENT '상세 정보',
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (admin_id) REFERENCES admins(id) ON DELETE RESTRICT,
    FOREIGN KEY (target_user_id) REFERENCES users(id) ON DELETE SET NULL,
    INDEX idx_admin_id (admin_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at)
);

-- ========================================
-- 샘플 데이터 (개발/테스트용)
-- ========================================

-- 관리자 생성 (비밀번호: admin123, bcrypt hash 예시)
INSERT INTO admins (id, name, email, password_hash, role) VALUES
('admin-001', '김관리', 'admin@example.com', '$2b$10$abcdefghijklmnopqrstuvwxyz1234567890', 'ADMIN');

-- 직원 생성
INSERT INTO users (id, name, email, department, position, is_eligible, hire_date) VALUES
('user-001', '홍길동', 'hong@example.com', '개발팀', '시니어 개발자', true, '2020-01-15'),
('user-002', '김철수', 'kim@example.com', '개발팀', '주니어 개발자', true, '2023-03-01'),
('user-003', '이영희', 'lee@example.com', '디자인팀', '디자이너', true, '2021-06-10'),
('user-004', '박민수', 'park@example.com', '기획팀', '기획자', false, '2025-11-01'),
('user-005', '최지은', 'choi@example.com', '마케팅팀', '마케터', true, '2022-02-20');

-- 휴가 잔액 초기화 (2026년)
INSERT INTO vacation_balances (id, user_id, year, total_days, used_days) VALUES
('balance-001', 'user-001', 2026, 15.00, 5.00),
('balance-002', 'user-002', 2026, 15.00, 2.00),
('balance-003', 'user-003', 2026, 15.00, 8.00),
('balance-004', 'user-004', 2026, 0.00, 0.00),
('balance-005', 'user-005', 2026, 15.00, 3.00);

-- 샘플 휴가 부여 기록
INSERT INTO vacation_assignments (id, user_id, admin_id, days_granted, reason, valid_from, valid_until) VALUES
('assign-001', 'user-001', 'admin-001', 5.00, '프로젝트 성공에 대한 보상', '2026-01-01', '2026-12-31'),
('assign-002', 'user-003', 'admin-001', 3.00, '추가 근무에 대한 보상', '2026-01-15', '2026-12-31');

-- ========================================
-- 유용한 쿼리 예시
-- ========================================

-- 1. 부여 대상자 목록 조회
-- SELECT id, name, email, department, position
-- FROM users
-- WHERE is_eligible = true
-- ORDER BY department, name;

-- 2. 특정 직원의 휴가 잔액 조회
-- SELECT u.name, vb.year, vb.total_days, vb.used_days, vb.remaining_days
-- FROM users u
-- JOIN vacation_balances vb ON u.id = vb.user_id
-- WHERE u.id = 'user-001' AND vb.year = 2026;

-- 3. 휴가 부여 이력 조회 (관리자 정보 포함)
-- SELECT va.id, u.name as user_name, a.name as admin_name,
--        va.days_granted, va.reason, va.valid_from, va.valid_until, va.created_at
-- FROM vacation_assignments va
-- JOIN users u ON va.user_id = u.id
-- JOIN admins a ON va.admin_id = a.id
-- ORDER BY va.created_at DESC
-- LIMIT 50;

-- 4. 부서별 휴가 사용 현황
-- SELECT u.department,
--        COUNT(DISTINCT u.id) as total_users,
--        SUM(vb.total_days) as total_vacation_days,
--        SUM(vb.used_days) as used_days,
--        SUM(vb.remaining_days) as remaining_days
-- FROM users u
-- LEFT JOIN vacation_balances vb ON u.id = vb.user_id AND vb.year = 2026
-- GROUP BY u.department;

-- ========================================
-- 인덱스 최적화 (필요시 추가)
-- ========================================
-- CREATE INDEX idx_vacation_assignments_user_created
--     ON vacation_assignments(user_id, created_at DESC);
--
-- CREATE INDEX idx_vacation_balances_user_year
--     ON vacation_balances(user_id, year);

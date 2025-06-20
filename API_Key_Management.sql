CREATE DATABASE API_Key_Management;

USE API_Key_Management;

-- =========================
-- 1. Users Table
-- =========================
CREATE TABLE users (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) UNIQUE NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 2. API Keys Table
-- =========================
CREATE TABLE api_keys (
    api_key_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    api_key VARCHAR(255) UNIQUE NOT NULL,
    status ENUM('active', 'inactive', 'revoked') DEFAULT 'active',
    environment ENUM('development', 'production') DEFAULT 'production',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    expires_at DATETIME,
    rate_limit_per_minute INT DEFAULT 60,
    FOREIGN KEY (user_id) REFERENCES users(user_id)
);

-- =========================
-- 3. API Key Usage Logs
-- =========================
CREATE TABLE api_usage_logs (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    api_key_id INT,
    used_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    status ENUM('success', 'rate_limit_exceeded', 'revoked') NOT NULL,
    FOREIGN KEY (api_key_id) REFERENCES api_keys(api_key_id)
);

-- =========================
-- 4. Admin Actions (Audit Logs)
-- =========================
CREATE TABLE admin_logs (
    log_id INT AUTO_INCREMENT PRIMARY KEY,
    action VARCHAR(255),
    api_key_id INT,
    action_time DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- =========================
-- 5. Function to Generate API Key
-- =========================
DELIMITER //
CREATE FUNCTION generate_api_key()
RETURNS VARCHAR(255)
DETERMINISTIC
BEGIN
    RETURN CONCAT(SHA2(UUID(), 256));
END //
DELIMITER ;

-- =========================
-- 6. Procedure: Generate API Key for a User
-- =========================
DELIMITER //
CREATE PROCEDURE generate_user_api_key(
    IN p_user_id INT,
    IN p_environment ENUM('development','production'),
    IN p_expires DATETIME
)
BEGIN
    DECLARE v_api_key VARCHAR(255);
    SET v_api_key = generate_api_key();

    INSERT INTO api_keys (user_id, api_key, environment, expires_at)
    VALUES (p_user_id, v_api_key, p_environment, p_expires);

    INSERT INTO admin_logs (action, api_key_id)
    VALUES ('API Key Generated', LAST_INSERT_ID());
END //
DELIMITER ;

-- =========================
-- 6b. Procedure: Bulk API Key Generation for a User
-- =========================
DELIMITER //
CREATE PROCEDURE bulk_generate_api_keys(
    IN p_user_id INT,
    IN p_environment ENUM('development','production'),
    IN p_expires DATETIME,
    IN p_count INT
)
BEGIN
    DECLARE i INT DEFAULT 0;

    WHILE i < p_count DO
        CALL generate_user_api_key(p_user_id, p_environment, p_expires);
        SET i = i + 1;
    END WHILE;
END //
DELIMITER ;

-- =========================
-- 7. Trigger: Revoke Expired Keys Automatically
-- =========================
SET GLOBAL event_scheduler = ON;
DELIMITER //
CREATE EVENT expire_keys_event
ON SCHEDULE EVERY 1 MINUTE
DO
BEGIN
    UPDATE api_keys
    SET status = 'inactive'
    WHERE expires_at IS NOT NULL AND expires_at < NOW() AND status = 'active';
END //
DELIMITER ;

-- =========================
-- 8. Procedure: Log API Usage with Rate Limiting
-- =========================
DELIMITER //
CREATE PROCEDURE log_api_usage(IN p_api_key VARCHAR(255))
BEGIN
    DECLARE v_api_key_id INT;
    DECLARE v_key_status ENUM('active', 'inactive', 'revoked');
    DECLARE v_log_status ENUM('success', 'rate_limit_exceeded', 'revoked');
    DECLARE v_limit INT;
    DECLARE v_recent_count INT;

    SELECT api_key_id, status, rate_limit_per_minute
    INTO v_api_key_id, v_key_status, v_limit
    FROM api_keys
    WHERE api_key = p_api_key;

    IF v_key_status != 'active' THEN
        SET v_log_status = 'revoked';
    ELSE
        SELECT COUNT(*) INTO v_recent_count
        FROM api_usage_logs
        WHERE api_key_id = v_api_key_id
          AND used_at >= NOW() - INTERVAL 1 MINUTE;

        IF v_recent_count >= v_limit THEN
            SET v_log_status = 'rate_limit_exceeded';
        ELSE
            SET v_log_status = 'success';
        END IF;
    END IF;

    INSERT INTO api_usage_logs (api_key_id, status)
    VALUES (v_api_key_id, v_log_status);
END //
DELIMITER ;

-- =========================
-- 9. Reporting Views
-- =========================
-- View: Usage per API Key
CREATE VIEW v_usage_per_key AS
SELECT ak.api_key, ak.user_id, COUNT(ul.log_id) AS total_calls
FROM api_keys ak
JOIN api_usage_logs ul ON ak.api_key_id = ul.api_key_id
GROUP BY ak.api_key_id;

-- View: Usage per User
CREATE VIEW v_usage_per_user AS
SELECT u.user_id, u.name, COUNT(ul.log_id) AS total_calls
FROM users u
JOIN api_keys ak ON u.user_id = ak.user_id
JOIN api_usage_logs ul ON ak.api_key_id = ul.api_key_id
GROUP BY u.user_id;

-- =========================
-- 10. Sample Data
-- =========================
INSERT INTO users (name, email) VALUES
('Gaurav', 'gaurav@rawat.com'),
('Mansi', 'mansi@patwal.com');

-- Generate API key for user 1 (example)
CALL generate_user_api_key(1, 'production', NOW() + INTERVAL 1 DAY);
CALL generate_user_api_key(2, 'development', NOW() + INTERVAL 2 DAY);

-- Bulk generate 5 keys for user 3
INSERT INTO users (name, email) VALUES
('Aman', 'aman@singh.com');
CALL bulk_generate_api_keys(3, 'production', NOW() + INTERVAL 5 DAY, 5);

-- Simulate usage (should be run multiple times to test rate limit)
CALL log_api_usage((SELECT api_key FROM api_keys WHERE user_id = 1 LIMIT 1));
CALL log_api_usage((SELECT api_key FROM api_keys WHERE user_id = 2 LIMIT 1));
CALL log_api_usage((SELECT api_key FROM api_keys WHERE user_id = 3 LIMIT 1));


SELECT * FROM api_usage_logs ORDER BY used_at DESC;
SELECT * FROM v_usage_per_key;
SELECT * FROM v_usage_per_user;
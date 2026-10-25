-- 04_security.sql
-- Crownfield Eye Hospital: Part D (roles, data protection, transactions, SQL injection)
-- Run after 01_schema.sql
USE crownfield_eye;

-- ============================================================
-- D1: Roles and privileges (four user types)
-- ============================================================
CREATE ROLE IF NOT EXISTS 'role_admin', 'role_doctor', 'role_receptionist', 'role_patient';

-- Administrator: full control
GRANT ALL PRIVILEGES ON crownfield_eye.* TO 'role_admin';

-- Doctor: read everything, record diagnoses and prescriptions
GRANT SELECT ON crownfield_eye.* TO 'role_doctor';
GRANT INSERT, UPDATE ON crownfield_eye.appointment_diagnosis TO 'role_doctor';
GRANT INSERT, UPDATE ON crownfield_eye.prescription TO 'role_doctor';
GRANT INSERT, UPDATE ON crownfield_eye.prescription_item TO 'role_doctor';

-- Receptionist: patients and appointments, no clinical writes, no deletes
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.patient TO 'role_receptionist';
GRANT SELECT, INSERT, UPDATE ON crownfield_eye.appointment TO 'role_receptionist';
GRANT SELECT ON crownfield_eye.clinician TO 'role_receptionist';
GRANT SELECT ON crownfield_eye.clinic TO 'role_receptionist';

-- Patient: limited view only (no direct table access)
CREATE OR REPLACE VIEW v_patient_appointments AS
SELECT p.patient_code, a.appointment_date, a.appointment_time, a.status
FROM patient p
INNER JOIN appointment a ON p.patient_id = a.patient_id;
GRANT SELECT ON crownfield_eye.v_patient_appointments TO 'role_patient';

SHOW GRANTS FOR 'role_doctor';
SHOW GRANTS FOR 'role_receptionist';
SHOW GRANTS FOR 'role_patient';

-- ============================================================
-- D2: Data protection (salted SHA-256 password hashing)
-- ============================================================
DROP TABLE IF EXISTS user_account;
CREATE TABLE user_account (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    username      VARCHAR(50) NOT NULL UNIQUE,
    role_name     VARCHAR(30) NOT NULL,
    salt          CHAR(16)    NOT NULL,
    password_hash CHAR(64)    NOT NULL
);

SET @s1 = LEFT(SHA2(UUID(), 256), 16);
SET @s2 = LEFT(SHA2(UUID(), 256), 16);

INSERT INTO user_account (username, role_name, salt, password_hash)
VALUES ('dr.shah',    'role_doctor',       @s1, SHA2(CONCAT(@s1, 'Secret123!'), 256)),
       ('reception1', 'role_receptionist', @s2, SHA2(CONCAT(@s2, 'Welcome456!'), 256));

-- Evidence 1: only hashes are stored
SELECT user_id, username, role_name, salt, password_hash FROM user_account;

-- Evidence 2: login check (1 = correct, 0 = wrong)
SELECT username,
       (password_hash = SHA2(CONCAT(salt, 'Secret123!'), 256)) AS right_password,
       (password_hash = SHA2(CONCAT(salt, 'WrongPass'), 256))  AS wrong_password
FROM user_account
WHERE username = 'dr.shah';

-- ============================================================
-- D3: Transaction with ROLLBACK (counts 15 -> 16 -> 15)
-- ============================================================
SET autocommit = 0;

SELECT COUNT(*) AS appointments_before FROM appointment;

START TRANSACTION;
INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time, status, notes)
VALUES (1, 1, 1, '2026-12-01', '09:30:00', 'Scheduled', 'Transaction demo');

SELECT COUNT(*) AS appointments_inside_transaction FROM appointment;

ROLLBACK;

SELECT COUNT(*) AS appointments_after_rollback FROM appointment;

SET autocommit = 1;

-- ============================================================
-- D4 (optional): SQL injection and a secure alternative
-- ============================================================
-- Vulnerable pattern (shown as a comment, never run): an application that builds
-- SQL by joining strings, for example:
--   "SELECT * FROM patient WHERE patient_code = '" + user_input + "'"
-- With user_input = OP001' OR '1'='1  the WHERE clause becomes always true
-- and every patient row is returned.

-- Secure version: a prepared statement treats the input as data, not SQL.
PREPARE safe_lookup FROM
  'SELECT patient_code, forename, surname FROM patient WHERE patient_code = ?';

SET @code = 'OP001';
EXECUTE safe_lookup USING @code;          -- returns 1 row

SET @code = "OP001' OR '1'='1";
EXECUTE safe_lookup USING @code;          -- returns 0 rows: the attack fails

DEALLOCATE PREPARE safe_lookup;

-- =====================================================================
-- 01_schema.sql  |  Crownfield Eye Hospital ophthalmology database
-- Module: CPU4103 Introduction to Databases  |  Fictional teaching scenario
-- Run order: 01_schema.sql -> 02_individual_queries.sql -> ...
-- Requires MySQL 8.0.16+ (CHECK constraints are enforced from that version)
-- ASSUMPTIONS
--  * Appendix 1 has no appointment ID, DOB, dose, route, frequency or
--    duration. Appointment IDs are surrogate keys; DOBs and prescription
--    details for the Appendix rows are synthetic placeholders.
--  * Follow-up "N weeks" is stored as due_date = appointment date + N weeks.
--  * Clinic belongs to the APPOINTMENT (Dr Shah works at two clinics).
--  * Appendix rows dated after 2026-10-25 are treated as planned appointments.
-- =====================================================================

DROP DATABASE IF EXISTS crownfield_eye;
CREATE DATABASE crownfield_eye CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE crownfield_eye;

-- ---------------------------------------------------------------------
-- 1. TABLES (parents first, then children)
-- ---------------------------------------------------------------------
CREATE TABLE specialty (
    specialty_id   INT AUTO_INCREMENT PRIMARY KEY,
    specialty_name VARCHAR(60) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE clinic (
    clinic_id   INT AUTO_INCREMENT PRIMARY KEY,
    clinic_name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE clinician (
    clinician_id INT AUTO_INCREMENT PRIMARY KEY,
    full_name    VARCHAR(80) NOT NULL UNIQUE,
    specialty_id INT NULL,                       -- "may have one primary specialty"
    CONSTRAINT fk_clinician_specialty FOREIGN KEY (specialty_id)
        REFERENCES specialty (specialty_id)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE patient (
    patient_id    INT AUTO_INCREMENT PRIMARY KEY,
    patient_code  VARCHAR(10) NOT NULL UNIQUE,   -- e.g. OP001 from Appendix 1
    forename      VARCHAR(50) NOT NULL,
    surname       VARCHAR(50) NOT NULL,
    date_of_birth DATE        NOT NULL,
    postcode      VARCHAR(10) NOT NULL,
    created_at    TIMESTAMP   NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_patient_code     CHECK (patient_code REGEXP '^OP[0-9]{3,}$'),
    CONSTRAINT chk_patient_postcode CHECK (CHAR_LENGTH(postcode) >= 5)
) ENGINE=InnoDB;

CREATE TABLE appointment (
    appointment_id   INT AUTO_INCREMENT PRIMARY KEY,
    patient_id       INT         NOT NULL,
    clinician_id     INT         NOT NULL,
    clinic_id        INT         NOT NULL,
    appointment_date DATE        NOT NULL,
    appointment_time TIME        NOT NULL,
    status           VARCHAR(20) NOT NULL DEFAULT 'Scheduled',
    notes            VARCHAR(255) NULL,
    CONSTRAINT fk_appt_patient   FOREIGN KEY (patient_id)   REFERENCES patient (patient_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appt_clinician FOREIGN KEY (clinician_id) REFERENCES clinician (clinician_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_appt_clinic    FOREIGN KEY (clinic_id)    REFERENCES clinic (clinic_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT uq_clinician_slot UNIQUE (clinician_id, appointment_date, appointment_time),
    CONSTRAINT chk_appt_status CHECK (status IN ('Scheduled','Attended','Cancelled','Did not attend')),
    CONSTRAINT chk_appt_time   CHECK (appointment_time BETWEEN '08:00:00' AND '18:00:00'),
    CONSTRAINT chk_appt_date   CHECK (appointment_date >= '2020-01-01')
) ENGINE=InnoDB;

CREATE TABLE diagnosis (
    diagnosis_id   INT AUTO_INCREMENT PRIMARY KEY,
    diagnosis_name VARCHAR(100) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- Link table: resolves appointment M:N diagnosis (zero or more per appointment)
CREATE TABLE appointment_diagnosis (
    appointment_id INT NOT NULL,
    diagnosis_id   INT NOT NULL,
    PRIMARY KEY (appointment_id, diagnosis_id),
    CONSTRAINT fk_ad_appointment FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_ad_diagnosis   FOREIGN KEY (diagnosis_id)   REFERENCES diagnosis (diagnosis_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB;

CREATE TABLE medicine (
    medicine_id   INT AUTO_INCREMENT PRIMARY KEY,
    medicine_name VARCHAR(80) NOT NULL UNIQUE,
    form          VARCHAR(30) NOT NULL DEFAULT 'Eye drops'
) ENGINE=InnoDB;

CREATE TABLE prescription (
    prescription_id INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id  INT  NOT NULL,
    issued_date     DATE NOT NULL,
    CONSTRAINT fk_rx_appointment FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB;

-- Link table: prescription M:N medicine, carrying dose/route/frequency/duration
CREATE TABLE prescription_item (
    prescription_id INT NOT NULL,
    medicine_id     INT NOT NULL,
    dose            VARCHAR(40) NOT NULL,
    route           VARCHAR(40) NOT NULL,
    frequency       VARCHAR(60) NOT NULL,
    duration_days   SMALLINT UNSIGNED NOT NULL,
    PRIMARY KEY (prescription_id, medicine_id),
    CONSTRAINT fk_pi_prescription FOREIGN KEY (prescription_id) REFERENCES prescription (prescription_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_pi_medicine FOREIGN KEY (medicine_id) REFERENCES medicine (medicine_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_pi_duration CHECK (duration_days > 0)
) ENGINE=InnoDB;

CREATE TABLE follow_up (
    follow_up_id   INT AUTO_INCREMENT PRIMARY KEY,
    appointment_id INT         NOT NULL UNIQUE,   -- at most one follow-up plan per appointment
    due_date       DATE        NOT NULL,
    priority       VARCHAR(10) NOT NULL DEFAULT 'Routine',
    status         VARCHAR(10) NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_fu_appointment FOREIGN KEY (appointment_id) REFERENCES appointment (appointment_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_fu_priority CHECK (priority IN ('Routine','High','Urgent')),
    CONSTRAINT chk_fu_status   CHECK (status IN ('Pending','Completed','Cancelled','Overdue'))
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- 2. ALTER TABLE examples
-- ---------------------------------------------------------------------
ALTER TABLE patient     ADD COLUMN phone VARCHAR(20) NULL AFTER postcode;
ALTER TABLE appointment ADD INDEX idx_appt_date (appointment_date);
ALTER TABLE patient     ADD CONSTRAINT chk_patient_dob CHECK (date_of_birth >= '1900-01-01');

-- ---------------------------------------------------------------------
-- 3. DATA: Appendix 1 rows first, then synthetic rows
-- ---------------------------------------------------------------------
INSERT INTO specialty (specialty_id, specialty_name) VALUES
(1,'Glaucoma'),(2,'Retina'),(3,'Cornea'),(4,'Cataract'),
(5,'Paediatric Ophthalmology'),(6,'Oculoplastics');

INSERT INTO clinic (clinic_id, clinic_name) VALUES
(1,'City Road'),(2,'Bedford'),(3,'Croydon'),(4,'Harbour View'),(5,'Northgate');

INSERT INTO clinician (clinician_id, full_name, specialty_id) VALUES
(1,'Dr Maya Shah',1),(2,'Dr Leo Grant',2),(3,'Dr Priya Nair',3),            -- Appendix 1
(4,'Dr Hannah Okafor',4),(5,'Dr Samuel Whitfield',1),(6,'Dr Priyanka Menon',2),
(7,'Dr Callum Reid',3),(8,'Dr Layla Haddad',5),(9,'Dr Tomasz Kowal',6),
(10,'Dr Grace Liu',4),(11,'Dr Omar Farouk',2),(12,'Dr Elena Rossi',1),
(13,'Dr Ben Adeyemi',3);                                                    -- synthetic

INSERT INTO patient (patient_id, patient_code, forename, surname, date_of_birth, postcode) VALUES
(1,'OP001','Amina','Yusuf','1971-03-14','NE1 4AB'),
(2,'OP002','Daniel','Reed','1964-09-02','N16 7QP'),
(3,'OP003','Sofia','Bennett','1980-01-27','E8 2LD'),
(4,'OP004','Michael','Okoro','1993-06-19','SE6 3RT'),                       -- Appendix 1
(5,'OP005','Chloe','Hartley','1958-11-30','M14 5GH'),
(6,'OP006','Rajesh','Patel','1975-04-08','LE2 7DP'),
(7,'OP007','Fatima','Noor','2001-12-21','B12 9QA'),
(8,'OP008','George','Whitaker','1949-07-05','S10 2TN'),
(9,'OP009','Ingrid','Larsen','1987-02-16','EH3 9DR'),
(10,'OP010','Tunde','Balogun','1969-10-11','CR0 1LH'),
(11,'OP011','Mei Lin','Zhao','1996-08-25','L8 7SS'),
(12,'OP012','Oliver','Hayes','2014-05-09','BS1 4DJ'),
(13,'OP013','Hannah','Pryce','1983-03-03','CF10 3AT'),
(14,'OP014','Samuel','Idowu','1977-09-29','NG1 5FS');                       -- synthetic (OP013, OP014 have no appointments)

INSERT INTO appointment (appointment_id, patient_id, clinician_id, clinic_id, appointment_date, appointment_time, status, notes) VALUES
(1, 1, 1, 1,'2026-10-05','09:00:00','Attended','Review IOP'),               -- Appendix 1
(2, 2, 2, 1,'2026-10-05','09:30:00','Attended','OCT before review'),
(3, 1, 1, 2,'2026-11-16','10:15:00','Scheduled','Visual field test'),
(4, 3, 1, 1,'2026-10-06','11:00:00','Attended','Monitor'),
(5, 4, 3, 3,'2026-10-07','14:00:00','Attended','Corneal topography'),
(6, 5, 4, 4,'2026-10-08','09:00:00','Attended','Pre-op cataract assessment'),   -- synthetic
(7, 6, 5, 1,'2026-10-08','10:00:00','Attended','Pressure check'),
(8, 7, 6, 2,'2026-10-09','11:30:00','Attended','Retinal imaging'),
(9, 8, 7, 5,'2026-10-12','14:30:00','Attended','Dry eye review'),
(10,12, 8, 4,'2026-10-13','09:15:00','Attended','Squint follow-up'),
(11, 9, 9, 3,'2026-10-14','13:00:00','Attended','Eyelid lesion review'),
(12,10,10, 1,'2026-10-15','10:45:00','Attended','Post-op check'),
(13,11,11, 5,'2026-10-19','15:00:00','Attended','Diabetic eye screening'),
(14, 2, 2, 1,'2026-11-02','09:30:00','Scheduled','Injection follow-up'),
(15, 5, 4, 4,'2026-11-05','09:00:00','Scheduled','Post-op review');

INSERT INTO diagnosis (diagnosis_id, diagnosis_name) VALUES
(1,'Ocular hypertension'),(2,'Diabetic macular oedema'),(3,'Glaucoma suspect'),(4,'Keratoconus'),  -- Appendix 1
(5,'Age-related cataract'),(6,'Primary open-angle glaucoma'),(7,'Posterior vitreous detachment'),
(8,'Dry eye disease'),(9,'Strabismus'),(10,'Chalazion'),(11,'Diabetic retinopathy'),
(12,'Allergic conjunctivitis'),(13,'Wet age-related macular degeneration'),(14,'Blepharitis');

INSERT INTO appointment_diagnosis (appointment_id, diagnosis_id) VALUES
(1,1),(2,2),(3,1),(4,3),(5,4),                                              -- Appendix 1
(6,5),(7,6),(8,7),(9,8),(9,14),(10,9),(11,10),(12,5),(13,11),(14,2);        -- synthetic (appt 15: none yet)

INSERT INTO medicine (medicine_id, medicine_name, form) VALUES
(1,'Latanoprost','Eye drops'),(2,'Timolol','Eye drops'),(3,'Aflibercept','Injection'),
(4,'Sodium chloride drops','Eye drops'),                                     -- Appendix 1
(5,'Dorzolamide','Eye drops'),(6,'Brimonidine','Eye drops'),(7,'Hypromellose','Eye drops'),
(8,'Chloramphenicol','Ointment'),(9,'Atropine','Eye drops'),(10,'Dexamethasone','Eye drops'),
(11,'Ranibizumab','Injection'),(12,'Olopatadine','Eye drops'),(13,'Cyclopentolate','Eye drops'),
(14,'Carbomer','Gel');

INSERT INTO prescription (prescription_id, appointment_id, issued_date) VALUES
(1,1,'2026-10-05'),(2,2,'2026-10-05'),(3,3,'2026-11-16'),(4,5,'2026-10-07'),   -- Appendix 1 (appt 4: "None")
(5,6,'2026-10-08'),(6,7,'2026-10-08'),(7,8,'2026-10-09'),(8,9,'2026-10-12'),
(9,10,'2026-10-13'),(10,11,'2026-10-14'),(11,12,'2026-10-15'),(12,13,'2026-10-19'),
(13,12,'2026-10-15'),(14,7,'2026-10-08');                                      -- synthetic (13, 14 = second prescription on one appointment)

-- Dose/route/frequency/duration are fictional placeholders (not in Appendix 1)
INSERT INTO prescription_item (prescription_id, medicine_id, dose, route, frequency, duration_days) VALUES
(1,1,'1 drop','Topical (eye)','Once daily at night',28),
(1,2,'1 drop','Topical (eye)','Twice daily',28),
(2,3,'2 mg','Intravitreal injection','Single dose',1),
(3,1,'1 drop','Topical (eye)','Once daily at night',28),
(4,4,'1 drop','Topical (eye)','Four times daily',14),
(5,8,'1 cm ribbon','Topical (eye)','Three times daily',7),
(6,5,'1 drop','Topical (eye)','Three times daily',28),
(7,10,'1 drop','Topical (eye)','Four times daily',14),
(8,7,'1 drop','Topical (eye)','As needed',30),
(9,9,'1 drop','Topical (eye)','Once daily',60),
(10,8,'1 cm ribbon','Topical (eye)','Three times daily',7),
(11,10,'1 drop','Topical (eye)','Four times daily',28),
(12,11,'0.5 mg','Intravitreal injection','Single dose',1),
(13,7,'1 drop','Topical (eye)','Four times daily',28),
(14,6,'1 drop','Topical (eye)','Twice daily',28);

INSERT INTO follow_up (appointment_id, due_date, priority, status) VALUES
(1,'2026-11-16','High','Pending'),    -- Appendix 1: 6 weeks | High
(2,'2026-11-02','Urgent','Pending'),  -- 4 weeks | Urgent
(3,'2027-02-08','Routine','Pending'), -- 12 weeks | Routine
(4,'2027-04-06','Routine','Pending'), -- 26 weeks | Routine
(5,'2026-12-02','Routine','Pending'), -- 8 weeks | Routine
(6,'2026-11-05','Routine','Pending'),(7,'2026-11-19','High','Pending'),
(8,'2026-11-20','Urgent','Pending'),(9,'2027-01-04','Routine','Pending'),
(10,'2026-12-15','Routine','Pending'),(11,'2026-11-25','Routine','Pending'),
(12,'2026-10-22','High','Overdue'),(13,'2026-12-14','High','Pending'),
(14,'2027-02-01','Routine','Pending'),(15,'2027-03-04','Routine','Pending');

-- ---------------------------------------------------------------------
-- 4. TEST LOG (screenshot each result for the report)
-- ---------------------------------------------------------------------
-- T1: row counts after load. Expected: patient 14, clinician 13, appointment 15,
--     diagnosis 14, medicine 14, prescription 14, prescription_item 15, follow_up 15
SELECT 'patient' AS tbl, COUNT(*) AS n FROM patient            UNION ALL
SELECT 'clinician',         COUNT(*) FROM clinician            UNION ALL
SELECT 'appointment',       COUNT(*) FROM appointment          UNION ALL
SELECT 'diagnosis',         COUNT(*) FROM diagnosis            UNION ALL
SELECT 'medicine',          COUNT(*) FROM medicine             UNION ALL
SELECT 'prescription',      COUNT(*) FROM prescription         UNION ALL
SELECT 'prescription_item', COUNT(*) FROM prescription_item    UNION ALL
SELECT 'follow_up',         COUNT(*) FROM follow_up;

-- T2: integrity tests. Run ONE at a time; each should FAIL with the stated error.
-- INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
--   VALUES (999, 1, 1, '2026-12-01', '09:00:00');         -- Error 1452: FK, patient 999 does not exist
-- INSERT INTO follow_up (appointment_id, due_date, priority) VALUES (4, '2027-05-01', 'Soon');
--                                                          -- Error 3819: CHECK chk_fu_priority (also duplicate appointment 4)
-- INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
--   VALUES (3, 1, 1, '2026-10-05', '09:00:00');            -- Error 1062: clinician double-booked
-- INSERT INTO appointment (patient_id, clinician_id, clinic_id, appointment_date, appointment_time)
--   VALUES (3, 1, 1, '2026-12-01', '23:30:00');            -- Error 3819: CHECK chk_appt_time

-- T3: controlled UPDATE (PK-targeted WHERE; no integrity impact)
UPDATE patient SET postcode = 'NE1 4AD' WHERE patient_code = 'OP001';
UPDATE follow_up SET status = 'Completed' WHERE follow_up_id = 12;   -- the overdue follow-up
SELECT patient_code, postcode FROM patient WHERE patient_code = 'OP001';
SELECT follow_up_id, due_date, status FROM follow_up WHERE follow_up_id = 12;

-- T4: controlled DELETE
-- (a) Blocked: OP001 has appointments, so ON DELETE RESTRICT protects clinical history.
-- DELETE FROM patient WHERE patient_code = 'OP001';          -- Error 1451
-- (b) Allowed: OP014 has no related rows, so referential integrity is not compromised.
DELETE FROM patient WHERE patient_code = 'OP014';
SELECT COUNT(*) AS patients_after_delete FROM patient;                -- Expected 13
-- (c) Cascade demo: removing one prescription removes its items but never the appointment.
DELETE FROM prescription WHERE prescription_id = 14;
SELECT COUNT(*) AS items_for_rx14 FROM prescription_item WHERE prescription_id = 14;  -- Expected 0
SELECT COUNT(*) AS appt_7_still_exists FROM appointment WHERE appointment_id = 7;     -- Expected 1

-- T5: orphan check. Every row below should return 0.
SELECT COUNT(*) AS orphan_appointments FROM appointment a
  LEFT JOIN patient p ON a.patient_id = p.patient_id WHERE p.patient_id IS NULL;

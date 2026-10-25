-- 03_procedure_and_trigger.sql
-- Crownfield Eye Hospital: Part C (C5 stored procedure, C6 trigger)
-- Run after 01_schema.sql
USE crownfield_eye;

-- C5: Stored procedure with an input parameter
-- Question: Show all appointments for one patient, given their patient code.
DROP PROCEDURE IF EXISTS sp_patient_appointments;

DELIMITER $$
CREATE PROCEDURE sp_patient_appointments(IN p_patient_code VARCHAR(10))
BEGIN
    SELECT a.appointment_id,
           a.appointment_date,
           a.appointment_time,
           c.full_name AS clinician,
           cl.clinic_name,
           a.status
    FROM patient p
    INNER JOIN appointment a  ON p.patient_id = a.patient_id
    INNER JOIN clinician c    ON a.clinician_id = c.clinician_id
    INNER JOIN clinic cl      ON a.clinic_id = cl.clinic_id
    WHERE p.patient_code = p_patient_code
    ORDER BY a.appointment_date, a.appointment_time;
END$$
DELIMITER ;

CALL sp_patient_appointments('OP001');

-- C6: Trigger enforcing a business rule
-- Rule: a follow-up cannot be due before its appointment date.
DROP TRIGGER IF EXISTS trg_followup_due_date;

DELIMITER $$
CREATE TRIGGER trg_followup_due_date
BEFORE INSERT ON follow_up
FOR EACH ROW
BEGIN
    DECLARE appt_date DATE;
    SELECT appointment_date INTO appt_date
    FROM appointment
    WHERE appointment_id = NEW.appointment_id;

    IF NEW.due_date < appt_date THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Follow-up due date cannot be before the appointment date';
    END IF;
END$$
DELIMITER ;

-- Trigger test (expected: Error 1644). Commented out so the script runs cleanly.
-- INSERT INTO follow_up (appointment_id, due_date, priority, status)
-- VALUES (1, '2026-10-01', 'Routine', 'Open');

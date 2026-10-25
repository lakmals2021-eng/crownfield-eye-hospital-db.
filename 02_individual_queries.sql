-- 02_individual_queries.sql
-- Crownfield Eye Hospital: Part C individual queries (C1 to C4)
-- Run after 01_schema.sql
USE crownfield_eye;

-- C1: Aggregate (GROUP BY + HAVING)
-- Question: Which clinicians have at least 2 appointments?
SELECT c.full_name AS clinician,
       COUNT(a.appointment_id) AS total_appointments
FROM clinician c
INNER JOIN appointment a ON c.clinician_id = a.clinician_id
GROUP BY c.clinician_id, c.full_name
HAVING COUNT(a.appointment_id) >= 2
ORDER BY total_appointments DESC;

-- C2: INNER JOIN across 4 tables
-- Question: List every appointment with patient, clinician and clinic.
SELECT p.patient_code,
       CONCAT(p.forename, ' ', p.surname) AS patient,
       c.full_name AS clinician,
       cl.clinic_name,
       a.appointment_date
FROM appointment a
INNER JOIN patient p   ON a.patient_id = p.patient_id
INNER JOIN clinician c ON a.clinician_id = c.clinician_id
INNER JOIN clinic cl   ON a.clinic_id = cl.clinic_id
ORDER BY a.appointment_date, a.appointment_time;

-- C3: LEFT JOIN (missing data)
-- Question: Which patients have never had an appointment?
SELECT p.patient_code,
       CONCAT(p.forename, ' ', p.surname) AS patient,
       a.appointment_id
FROM patient p
LEFT JOIN appointment a ON p.patient_id = a.patient_id
WHERE a.appointment_id IS NULL;

-- C4: Subquery
-- Question: Which patients have an Urgent follow-up?
SELECT p.patient_code,
       CONCAT(p.forename, ' ', p.surname) AS patient
FROM patient p
WHERE p.patient_id IN (
    SELECT a.patient_id
    FROM appointment a
    INNER JOIN follow_up f ON a.appointment_id = f.appointment_id
    WHERE f.priority = 'Urgent'
);

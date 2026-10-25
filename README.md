# Crownfield Eye Hospital Database (CPU4103 Introduction to Databases)

Individual repository for the fictional Crownfield Eye Hospital ophthalmology database.
Fictional teaching scenario only; all data is synthetic.

**Student:** SUchithra Lakmal Andrahannadi | **Student ID:** G276481 | **Module:** CPU4103 Introduction to Databases

## Requirements
- MySQL 8.0.16 or later (needed for enforced CHECK constraints, roles and SIGNAL)
- MySQL Workbench (or any MySQL client)
- A MySQL account that can create databases, roles and users (for example `root`)

## Setup and execution order
Run the files in this order. Each file starts with `USE crownfield_eye;` except 01, which creates the database.

| Step | File | What it does |
|------|------|--------------|
| 1 | `01_schema.sql` | Drops and recreates the `crownfield_eye` database. Creates 11 tables with PK, FK, UNIQUE, NOT NULL, DEFAULT and CHECK constraints, ALTER TABLE examples, synthetic data (at least 10 rows per main table plus the Appendix 1 records), controlled UPDATE and DELETE tests, and the test log |
| 2 | `02_individual_queries.sql` | Part C queries C1 to C4: GROUP BY with HAVING, 4-table INNER JOIN, LEFT JOIN, subquery |
| 3 | `03_procedure_and_trigger.sql` | C5 stored procedure `sp_patient_appointments(IN p_patient_code)` and C6 trigger `trg_followup_due_date` |
| 4 | `04_security.sql` | Part D: four roles with GRANTs and a patient view, salted SHA-256 password hashing, transaction with ROLLBACK, and an optional SQL injection demo with a prepared statement |

In MySQL Workbench: File > Open SQL Script, then run the whole script with **Ctrl + Shift + Enter**.
Do not use the "Run SQL Script" dialog if it fails with a temp-file error; open the file in a normal SQL tab instead.

## Repository structure
```
01_schema.sql
02_individual_queries.sql
03_procedure_and_trigger.sql
04_security.sql
05_ERD/          conceptual and logical ERD (.drawio originals and PNG exports)
README.md
```

## Tables
specialty, clinic, clinician, patient, appointment, diagnosis, appointment_diagnosis (link),
medicine, prescription, prescription_item (link), follow_up. `04_security.sql` adds `user_account`
and the view `v_patient_appointments`.

## Assumptions
- A clinician has zero or one primary specialty (nullable foreign key).
- An appointment has at most one follow-up plan (UNIQUE foreign key in `follow_up`).
- Many-to-many relationships (appointment to diagnosis, prescription to medicine) are resolved with link tables. The prescription link table also stores dose, route, frequency and duration.
- A clinician cannot be double-booked: UNIQUE (clinician_id, appointment_date, appointment_time).
- Appointment times are limited to 08:00 to 18:00 and statuses, follow-up priorities and statuses are restricted by CHECK constraints.
- MySQL CHECK constraints cannot use CURDATE() or NOW(), so date-against-today rules would need a trigger. The implemented trigger instead enforces that a follow-up is not due before its appointment date.
- Roles are created and granted privileges as a demonstration. They are not assigned to real MySQL user accounts.
- Passwords in `user_account` are stored as SHA-256 of a random per-user salt plus the password. A production system should use a slow password hashing function such as bcrypt or Argon2 in the application layer.
- All names, dates and clinical details are synthetic.

## My individual contribution
[Write 3 to 5 sentences: which parts you designed and wrote yourself (for example Part C queries C1 to C6, Part D security and transactions), and which parts were shared group work (schema and data).]

## Evidence
Screenshots are included in the report and slides: row counts, integrity errors (1452, 3819, 1062), queries C1 to C6, role grants, hashing, transaction rollback and SQL injection test.

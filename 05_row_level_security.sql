-- ============================================================
-- LuxUniversity DB
-- FILE: 05_row_level_security.sql
-- PURPOSE: Row-Level Security policies, database users,
--          and role-based access control
-- RUN AFTER: 01_create_oltp.sql, 03_insert_sample_data.sql
-- ============================================================
-- ROLES IMPLEMENTED:
--   student_role    -> sees only their own student record,
--                      registrations, and results
--   lecturer_role   -> sees students in courses they teach
--   faculty_admin   -> sees all students in their faculty
--   registry_admin  -> sees everything (bypasses RLS)
--   dw_etl_user     -> read-only on OLTP for ETL pipeline
-- ============================================================

USE luxuniversity_db;
GO

-- ============================================================
-- SECTION 1: DATABASE ROLES
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='student_role')
    CREATE ROLE student_role;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='lecturer_role')
    CREATE ROLE lecturer_role;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='faculty_admin_role')
    CREATE ROLE faculty_admin_role;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='registry_admin_role')
    CREATE ROLE registry_admin_role;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name='dw_etl_role')
    CREATE ROLE dw_etl_role;
GO

-- ============================================================
-- SECTION 2: PERMISSIONS PER ROLE
-- ============================================================

-- Student: read own data only (RLS enforces row filtering)
GRANT SELECT ON dbo.student                 TO student_role;
GRANT SELECT ON dbo.course_registration     TO student_role;
GRANT SELECT ON dbo.course_result           TO student_role;
GRANT SELECT ON dbo.course                  TO student_role;
GRANT SELECT ON dbo.course_prerequisite     TO student_role;
GRANT SELECT ON dbo.semester                TO student_role;
GRANT SELECT ON dbo.academic_session        TO student_role;
GRANT SELECT ON dbo.student_level           TO student_role;
GRANT SELECT ON dbo.student_level_history   TO student_role;
GRANT SELECT ON dbo.programme               TO student_role;
GRANT SELECT ON dbo.department              TO student_role;
GRANT SELECT ON dbo.faculty                 TO student_role;
GRANT SELECT ON dbo.grade_scale             TO student_role;
-- Students can execute transcript procedure on themselves
GRANT EXECUTE ON dbo.sp_get_transcript      TO student_role;
GRANT EXECUTE ON dbo.sp_get_student_courses TO student_role;
GO

-- Lecturer: read student data for courses they teach
GRANT SELECT ON dbo.student                 TO lecturer_role;
GRANT SELECT ON dbo.course_registration     TO lecturer_role;
GRANT SELECT ON dbo.course_result           TO lecturer_role;
GRANT SELECT ON dbo.course                  TO lecturer_role;
GRANT SELECT ON dbo.course_assignment       TO lecturer_role;
GRANT SELECT ON dbo.semester                TO lecturer_role;
GRANT SELECT ON dbo.academic_session        TO lecturer_role;
GRANT SELECT ON dbo.student_level           TO lecturer_role;
GRANT SELECT ON dbo.programme               TO lecturer_role;
GRANT SELECT ON dbo.department              TO lecturer_role;
GRANT SELECT ON dbo.faculty                 TO lecturer_role;
GRANT SELECT ON dbo.grade_scale             TO lecturer_role;
-- Lecturers can enter results for their courses
GRANT INSERT, UPDATE ON dbo.course_result   TO lecturer_role;
GO

-- Faculty admin: full read within faculty + can register courses
GRANT SELECT ON dbo.student                 TO faculty_admin_role;
GRANT SELECT ON dbo.course_registration     TO faculty_admin_role;
GRANT SELECT ON dbo.course_result           TO faculty_admin_role;
GRANT SELECT ON dbo.course                  TO faculty_admin_role;
GRANT SELECT ON dbo.semester                TO faculty_admin_role;
GRANT SELECT ON dbo.academic_session        TO faculty_admin_role;
GRANT SELECT ON dbo.student_level           TO faculty_admin_role;
GRANT SELECT ON dbo.student_level_history   TO faculty_admin_role;
GRANT SELECT ON dbo.programme               TO faculty_admin_role;
GRANT SELECT ON dbo.department              TO faculty_admin_role;
GRANT SELECT ON dbo.faculty                 TO faculty_admin_role;
GRANT SELECT ON dbo.staff                   TO faculty_admin_role;
GRANT SELECT ON dbo.course_assignment       TO faculty_admin_role;
GRANT SELECT ON dbo.grade_scale             TO faculty_admin_role;
GRANT SELECT ON dbo.registration_audit      TO faculty_admin_role;
GRANT EXECUTE ON dbo.sp_register_course     TO faculty_admin_role;
GRANT EXECUTE ON dbo.sp_get_transcript      TO faculty_admin_role;
GRANT EXECUTE ON dbo.sp_get_student_courses TO faculty_admin_role;
GRANT EXECUTE ON dbo.sp_promote_student     TO faculty_admin_role;
GO

-- Registry admin: full access to everything
GRANT SELECT, INSERT, UPDATE ON dbo.student                 TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.course_registration     TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.course_result           TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.student_level_history   TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.course                  TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.semester                TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.academic_session        TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.staff                   TO registry_admin_role;
GRANT SELECT, INSERT, UPDATE ON dbo.course_assignment       TO registry_admin_role;
GRANT SELECT ON dbo.registration_audit                      TO registry_admin_role;
GRANT SELECT ON dbo.dq_check_log                            TO registry_admin_role;
GRANT EXECUTE ON dbo.sp_register_course                     TO registry_admin_role;
GRANT EXECUTE ON dbo.sp_promote_student                     TO registry_admin_role;
GRANT EXECUTE ON dbo.sp_get_transcript                      TO registry_admin_role;
GRANT EXECUTE ON dbo.sp_get_student_courses                 TO registry_admin_role;
GO

-- ETL user: read-only on all tables (for DW pipeline)
GRANT SELECT ON dbo.student                 TO dw_etl_role;
GRANT SELECT ON dbo.course                  TO dw_etl_role;
GRANT SELECT ON dbo.course_registration     TO dw_etl_role;
GRANT SELECT ON dbo.course_result           TO dw_etl_role;
GRANT SELECT ON dbo.semester                TO dw_etl_role;
GRANT SELECT ON dbo.academic_session        TO dw_etl_role;
GRANT SELECT ON dbo.faculty                 TO dw_etl_role;
GRANT SELECT ON dbo.department              TO dw_etl_role;
GRANT SELECT ON dbo.programme               TO dw_etl_role;
GRANT SELECT ON dbo.student_level           TO dw_etl_role;
GRANT SELECT ON dbo.degree_type             TO dw_etl_role;
GRANT SELECT ON dbo.course_category         TO dw_etl_role;
GRANT SELECT ON dbo.course_prerequisite     TO dw_etl_role;
GRANT SELECT ON dbo.course_assignment       TO dw_etl_role;
GRANT SELECT ON dbo.staff                   TO dw_etl_role;
GRANT SELECT ON dbo.grade_scale             TO dw_etl_role;
GRANT SELECT ON dbo.registration_audit      TO dw_etl_role;
GRANT SELECT ON dbo.student_level_history   TO dw_etl_role;
GRANT SELECT ON dbo.etl_watermark           TO dw_etl_role;
-- ETL needs to update watermarks after successful run
GRANT UPDATE ON dbo.etl_watermark           TO dw_etl_role;
-- ETL needs to insert DQ check results
GRANT INSERT ON dbo.dq_check_log            TO dw_etl_role;
GO

-- ============================================================
-- SECTION 3: SAMPLE DATABASE USERS
-- These are contained database users (no SQL login needed).
-- Assign real users to roles in production.
-- ============================================================

-- Example: create sample users (comment out if managing via AD)
-- CREATE USER student_adebayo WITHOUT LOGIN;
-- ALTER ROLE student_role ADD MEMBER student_adebayo;

-- CREATE USER lecturer_adeyemi WITHOUT LOGIN;
-- ALTER ROLE lecturer_role ADD MEMBER lecturer_adeyemi;

-- CREATE USER faculty_admin_cst WITHOUT LOGIN;
-- ALTER ROLE faculty_admin_role ADD MEMBER faculty_admin_cst;

-- CREATE USER registry_admin WITHOUT LOGIN;
-- ALTER ROLE registry_admin_role ADD MEMBER registry_admin;

-- CREATE USER dw_etl_svc WITHOUT LOGIN;
-- ALTER ROLE dw_etl_role ADD MEMBER dw_etl_svc;

-- ============================================================
-- SECTION 4: SECURITY USER MAP
-- Maps each database user to their entity_id and faculty_id.
-- This table is READ by the RLS predicate function.
-- Populate this whenever a new user account is created.
-- ============================================================
INSERT INTO security_user_map (db_username, role_name, entity_id, faculty_id)
VALUES
-- Format: (db_username, role, entity_id [student_id/staff_id/null], faculty_id)
('student_adebayo',  'student',       1, NULL),  -- student_id = 1
('student_chioma',   'student',       2, NULL),  -- student_id = 2
('lecturer_adeyemi', 'lecturer',      1, NULL),  -- staff_id = 1
('lecturer_bakare',  'lecturer',      8, NULL),  -- staff_id = 8 (English)
('fadmin_cst',       'faculty_admin', NULL, 14), -- faculty_id = 14 (CST)
('fadmin_soc',       'faculty_admin', NULL, 12), -- faculty_id = 12 (Social Sciences)
('registry_admin',   'registry_admin',NULL, NULL);
GO

-- ============================================================
-- SECTION 5: RLS POLICY (already created in 01_create_oltp.sql)
-- The predicate fn_rls_student_predicate is already applied.
-- This section shows how to verify and manage the policy.
-- ============================================================

-- Verify RLS is active:
-- SELECT name, is_enabled, type_desc FROM sys.security_policies;

-- Temporarily disable for admin maintenance:
-- ALTER SECURITY POLICY rls_student_policy WITH (STATE = OFF);

-- Re-enable after maintenance:
-- ALTER SECURITY POLICY rls_student_policy WITH (STATE = ON);

-- Test RLS as a specific user (run in a new session):
-- EXECUTE AS USER = 'student_adebayo';
-- SELECT * FROM student;  -- should return only 1 row
-- REVERT;

-- ============================================================
-- SECTION 6: TEMPORAL TABLE QUERY EXAMPLES
-- The student table is system-versioned (temporal).
-- These queries work without any additional setup.
-- ============================================================

-- See what a student record looked like on a specific date:
-- SELECT * FROM student FOR SYSTEM_TIME AS OF '2023-06-01'
-- WHERE student_matric_no = 'CST/2022/001';

-- See all historical versions of a student record:
-- SELECT * FROM student FOR SYSTEM_TIME ALL
-- WHERE student_matric_no = 'CST/2022/001'
-- ORDER BY valid_from;

-- See all changes to any student between two dates:
-- SELECT * FROM student
-- FOR SYSTEM_TIME BETWEEN '2023-01-01' AND '2024-01-01'
-- ORDER BY student_matric_no, valid_from;

-- ============================================================
-- END OF 05_row_level_security.sql
-- ============================================================

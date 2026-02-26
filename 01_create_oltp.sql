-- ============================================================
-- LuxUniversity DB
-- FILE: 01_create_oltp.sql
-- PURPOSE: Create the OLTP (transactional) database
-- ENGINE: Microsoft SQL Server 2016+ / Azure SQL Database
-- ============================================================
-- This database handles ALL day-to-day university operations:
--   student enrolment, course registration, grading, staff.
-- It is the SINGLE SOURCE OF TRUTH for the data warehouse.
-- The DW (luxuniversity_dw) is populated FROM this database.
-- ============================================================

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'luxuniversity_db')
BEGIN
    ALTER DATABASE luxuniversity_db SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE luxuniversity_db;
END
GO

CREATE DATABASE luxuniversity_db COLLATE Latin1_General_CI_AS;
GO

USE luxuniversity_db;
GO

-- ============================================================
-- SECTION 1: ETL WATERMARK TABLE
-- Tracks the last time each entity was synced to the DW.
-- The ETL reads this to perform incremental loads.
-- ============================================================
CREATE TABLE etl_watermark (
    watermark_id        INT IDENTITY(1,1)   PRIMARY KEY,
    entity_name         NVARCHAR(100)       NOT NULL UNIQUE,  -- e.g. 'course_result'
    last_extracted_at   DATETIME2           NOT NULL DEFAULT '1900-01-01',
    last_row_count      INT                 NOT NULL DEFAULT 0,
    updated_at          DATETIME2           NOT NULL DEFAULT GETDATE()
);
GO

-- Pre-seed watermarks for every entity the ETL will extract
INSERT INTO etl_watermark (entity_name) VALUES
('student'), ('course'), ('course_registration'),
('course_result'), ('student_level_history'),
('programme'), ('department'), ('faculty'),
('semester'), ('academic_session'), ('staff');
GO

-- ============================================================
-- SECTION 2: REFERENCE / LOOKUP TABLES
-- ============================================================

CREATE TABLE academic_session (
    session_id      INT IDENTITY(1,1)   PRIMARY KEY,
    session_name    NVARCHAR(20)        NOT NULL UNIQUE,
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    is_current      BIT                 NOT NULL DEFAULT 0,
    created_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT chk_session_dates CHECK (end_date > start_date)
);
GO

CREATE TABLE semester (
    semester_id     INT IDENTITY(1,1)   PRIMARY KEY,
    session_id      INT                 NOT NULL,
    semester_name   NVARCHAR(10)        NOT NULL,
    start_date      DATE                NOT NULL,
    end_date        DATE                NOT NULL,
    reg_deadline    DATE                NOT NULL,
    is_current      BIT                 NOT NULL DEFAULT 0,
    created_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    updated_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_semester_session  FOREIGN KEY (session_id) REFERENCES academic_session(session_id),
    CONSTRAINT uq_semester          UNIQUE (session_id, semester_name),
    CONSTRAINT chk_semester_dates   CHECK (end_date > start_date),
    CONSTRAINT chk_reg_deadline     CHECK (reg_deadline <= end_date),
    CONSTRAINT chk_semester_name    CHECK (semester_name IN ('First','Second'))
);
GO

CREATE TABLE student_level (
    level_id        INT IDENTITY(1,1)   PRIMARY KEY,
    level_name      NVARCHAR(10)        NOT NULL UNIQUE,
    level_number    INT                 NOT NULL UNIQUE,
    description     NVARCHAR(200)
);
GO

CREATE TABLE degree_type (
    degree_type_id  INT IDENTITY(1,1)   PRIMARY KEY,
    degree_code     NVARCHAR(15)        NOT NULL UNIQUE,
    degree_name     NVARCHAR(100)       NOT NULL
);
GO

CREATE TABLE grade_scale (
    grade_scale_id  INT IDENTITY(1,1)   PRIMARY KEY,
    grade           NVARCHAR(5)         NOT NULL UNIQUE,
    min_score       INT                 NOT NULL,
    max_score       INT                 NOT NULL,
    grade_point     DECIMAL(3,1)        NOT NULL,
    remark          NVARCHAR(30)
);
GO

-- ============================================================
-- SECTION 3: INSTITUTIONAL STRUCTURE
-- ============================================================

CREATE TABLE college (
    college_id      INT IDENTITY(1,1)   PRIMARY KEY,
    college_name    NVARCHAR(150)       NOT NULL UNIQUE,
    abbreviation    NVARCHAR(25),
    updated_at      DATETIME2           NOT NULL DEFAULT GETDATE()
);
GO

CREATE TABLE faculty (
    faculty_id          INT IDENTITY(1,1)   PRIMARY KEY,
    college_id          INT                 NULL,
    faculty_name        NVARCHAR(200)       NOT NULL UNIQUE,
    abbreviation        NVARCHAR(25)        NOT NULL UNIQUE,
    established_year    INT,
    updated_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_faculty_college FOREIGN KEY (college_id) REFERENCES college(college_id)
);
GO

CREATE TABLE department (
    department_id   INT IDENTITY(1,1)   PRIMARY KEY,
    faculty_id      INT                 NOT NULL,
    department_name NVARCHAR(200)       NOT NULL,
    abbreviation    NVARCHAR(25),
    hod_name        NVARCHAR(200),
    updated_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_dept_faculty  FOREIGN KEY (faculty_id) REFERENCES faculty(faculty_id),
    CONSTRAINT uq_dept_faculty  UNIQUE (faculty_id, department_name)
);
GO

CREATE TABLE programme (
    programme_id    INT IDENTITY(1,1)   PRIMARY KEY,
    department_id   INT                 NOT NULL,
    degree_type_id  INT                 NOT NULL,
    programme_name  NVARCHAR(250)       NOT NULL,
    duration_years  INT                 NOT NULL DEFAULT 4,
    updated_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_prog_dept   FOREIGN KEY (department_id)  REFERENCES department(department_id),
    CONSTRAINT fk_prog_degree FOREIGN KEY (degree_type_id) REFERENCES degree_type(degree_type_id)
);
GO

-- ============================================================
-- SECTION 4: COURSE CATALOG
-- ============================================================

CREATE TABLE course_category (
    category_id     INT IDENTITY(1,1)   PRIMARY KEY,
    category_code   NVARCHAR(25)        NOT NULL UNIQUE,
    category_name   NVARCHAR(100)       NOT NULL,
    description     NVARCHAR(MAX)
);
GO

CREATE TABLE course (
    course_id           INT IDENTITY(1,1)   PRIMARY KEY,
    department_id       INT                 NOT NULL,
    category_id         INT                 NOT NULL,
    course_code         NVARCHAR(15)        NOT NULL UNIQUE,
    course_title        NVARCHAR(300)       NOT NULL,
    course_description  NVARCHAR(MAX),
    credit_units        INT                 NOT NULL DEFAULT 2,
    level_id            INT                 NOT NULL,
    semester_offered    NVARCHAR(10)        NOT NULL DEFAULT 'First',
    is_active           BIT                 NOT NULL DEFAULT 1,
    is_compulsory_se    BIT                 NOT NULL DEFAULT 0,
    created_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_course_dept       FOREIGN KEY (department_id) REFERENCES department(department_id),
    CONSTRAINT fk_course_category   FOREIGN KEY (category_id)   REFERENCES course_category(category_id),
    CONSTRAINT fk_course_level      FOREIGN KEY (level_id)      REFERENCES student_level(level_id),
    CONSTRAINT chk_semester_offered CHECK (semester_offered IN ('First','Second','Both'))
);
GO

CREATE TABLE course_prerequisite (
    prerequisite_id     INT IDENTITY(1,1)   PRIMARY KEY,
    course_id           INT                 NOT NULL,
    required_course_id  INT                 NOT NULL,
    min_grade           NVARCHAR(5)         NOT NULL DEFAULT 'E',
    CONSTRAINT fk_prereq_course     FOREIGN KEY (course_id)          REFERENCES course(course_id),
    CONSTRAINT fk_prereq_required   FOREIGN KEY (required_course_id) REFERENCES course(course_id),
    CONSTRAINT uq_prereq            UNIQUE (course_id, required_course_id),
    CONSTRAINT chk_no_self_prereq   CHECK  (course_id <> required_course_id)
);
GO

CREATE TABLE programme_course (
    programme_course_id INT IDENTITY(1,1)   PRIMARY KEY,
    programme_id        INT                 NOT NULL,
    course_id           INT                 NOT NULL,
    course_type         NVARCHAR(20)        NOT NULL,
    is_compulsory       BIT                 NOT NULL DEFAULT 1,
    CONSTRAINT fk_pc_programme  FOREIGN KEY (programme_id) REFERENCES programme(programme_id),
    CONSTRAINT fk_pc_course     FOREIGN KEY (course_id)    REFERENCES course(course_id),
    CONSTRAINT uq_prog_course   UNIQUE (programme_id, course_id),
    CONSTRAINT chk_pc_type      CHECK (course_type IN ('MAJOR','ELECTIVE','COMPULSORY_SE'))
);
GO

-- ============================================================
-- SECTION 5: STUDENT MANAGEMENT
-- System-versioned temporal table for full audit history.
-- SQL Server automatically tracks ALL changes with timestamps.
-- Query: SELECT * FROM student FOR SYSTEM_TIME AS OF '2023-01-01'
-- ============================================================

CREATE TABLE student (
    student_id              INT IDENTITY(1,1)   PRIMARY KEY,
    student_matric_no       NVARCHAR(30)        NOT NULL UNIQUE,
    first_name              NVARCHAR(100)       NOT NULL,
    last_name               NVARCHAR(100)       NOT NULL,
    middle_name             NVARCHAR(100),
    date_of_birth           DATE,
    gender                  NVARCHAR(10),
    email                   NVARCHAR(200)       UNIQUE,
    phone                   NVARCHAR(25),
    address                 NVARCHAR(MAX),
    state_of_origin         NVARCHAR(80),
    programme_id            INT                 NOT NULL,
    current_level_id        INT                 NOT NULL,
    admission_session_id    INT                 NOT NULL,
    enrollment_status       NVARCHAR(20)        NOT NULL DEFAULT 'Active',
    created_at              DATETIME2           NOT NULL DEFAULT GETDATE(),
    updated_at              DATETIME2           NOT NULL DEFAULT GETDATE(),
    -- Temporal table system columns
    valid_from              DATETIME2 GENERATED ALWAYS AS ROW START NOT NULL,
    valid_to                DATETIME2 GENERATED ALWAYS AS ROW END   NOT NULL,
    PERIOD FOR SYSTEM_TIME (valid_from, valid_to),
    CONSTRAINT fk_student_programme FOREIGN KEY (programme_id)         REFERENCES programme(programme_id),
    CONSTRAINT fk_student_level     FOREIGN KEY (current_level_id)     REFERENCES student_level(level_id),
    CONSTRAINT fk_student_session   FOREIGN KEY (admission_session_id) REFERENCES academic_session(session_id),
    CONSTRAINT chk_student_gender   CHECK (gender IN ('Male','Female','Other')),
    CONSTRAINT chk_enrollment       CHECK (enrollment_status IN ('Active','Suspended','Withdrawn','Graduated','Deferred'))
)
WITH (SYSTEM_VERSIONING = ON (HISTORY_TABLE = dbo.student_history));
GO

CREATE TABLE student_level_history (
    history_id              INT IDENTITY(1,1)   PRIMARY KEY,
    student_id              INT                 NOT NULL,
    session_id              INT                 NOT NULL,
    level_id                INT                 NOT NULL,
    gpa                     DECIMAL(4,2),
    cgpa                    DECIMAL(4,2),
    total_credits_earned    INT                 NOT NULL DEFAULT 0,
    recorded_at             DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_slh_student   FOREIGN KEY (student_id) REFERENCES student(student_id),
    CONSTRAINT fk_slh_session   FOREIGN KEY (session_id) REFERENCES academic_session(session_id),
    CONSTRAINT fk_slh_level     FOREIGN KEY (level_id)   REFERENCES student_level(level_id),
    CONSTRAINT uq_student_session UNIQUE (student_id, session_id)
);
GO

-- ============================================================
-- SECTION 6: COURSE REGISTRATION
-- ============================================================

CREATE TABLE course_registration (
    registration_id     INT IDENTITY(1,1)   PRIMARY KEY,
    student_id          INT                 NOT NULL,
    course_id           INT                 NOT NULL,
    semester_id         INT                 NOT NULL,
    registration_date   DATETIME2           NOT NULL DEFAULT GETDATE(),
    registration_status NVARCHAR(20)        NOT NULL DEFAULT 'Registered',
    course_type_taken   NVARCHAR(20)        NOT NULL,
    updated_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_reg_student   FOREIGN KEY (student_id)  REFERENCES student(student_id),
    CONSTRAINT fk_reg_course    FOREIGN KEY (course_id)   REFERENCES course(course_id),
    CONSTRAINT fk_reg_semester  FOREIGN KEY (semester_id) REFERENCES semester(semester_id),
    CONSTRAINT uq_student_course_sem UNIQUE (student_id, course_id, semester_id),
    CONSTRAINT chk_reg_status   CHECK (registration_status IN ('Registered','Dropped','Completed')),
    CONSTRAINT chk_reg_type     CHECK (course_type_taken  IN ('MAJOR','ELECTIVE','COMPULSORY_SE'))
);
GO

CREATE TABLE registration_audit (
    audit_id            INT IDENTITY(1,1)   PRIMARY KEY,
    student_id          INT                 NOT NULL,
    course_id           INT                 NOT NULL,
    semester_id         INT                 NOT NULL,
    attempt_time        DATETIME2           NOT NULL DEFAULT GETDATE(),
    was_late            BIT                 NOT NULL DEFAULT 0,
    prereqs_failed      INT                 NOT NULL DEFAULT 0,
    rejection_reason    NVARCHAR(500),
    CONSTRAINT fk_audit_student  FOREIGN KEY (student_id)  REFERENCES student(student_id),
    CONSTRAINT fk_audit_course   FOREIGN KEY (course_id)   REFERENCES course(course_id),
    CONSTRAINT fk_audit_semester FOREIGN KEY (semester_id) REFERENCES semester(semester_id)
);
GO

-- ============================================================
-- SECTION 7: RESULTS
-- ============================================================

CREATE TABLE course_result (
    result_id           INT IDENTITY(1,1)   PRIMARY KEY,
    registration_id     INT                 NOT NULL UNIQUE,
    ca_score            DECIMAL(5,2),
    exam_score          DECIMAL(5,2),
    total_score         AS (ISNULL(ca_score,0) + ISNULL(exam_score,0)) PERSISTED,
    grade               NVARCHAR(5),
    grade_point         DECIMAL(3,1),
    credit_units_earned INT                 NOT NULL DEFAULT 0,
    remark              NVARCHAR(20)        NOT NULL DEFAULT 'Pass',
    entered_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    updated_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_result_reg    FOREIGN KEY (registration_id) REFERENCES course_registration(registration_id),
    CONSTRAINT chk_result_remark CHECK (remark IN ('Pass','Fail','Absent','Withheld'))
);
GO

-- ============================================================
-- SECTION 8: STAFF
-- ============================================================

CREATE TABLE staff (
    staff_id        INT IDENTITY(1,1)   PRIMARY KEY,
    staff_no        NVARCHAR(30)        NOT NULL UNIQUE,
    first_name      NVARCHAR(100)       NOT NULL,
    last_name       NVARCHAR(100)       NOT NULL,
    department_id   INT                 NOT NULL,
    designation     NVARCHAR(100),
    email           NVARCHAR(200)       UNIQUE,
    is_active       BIT                 NOT NULL DEFAULT 1,
    updated_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    CONSTRAINT fk_staff_dept FOREIGN KEY (department_id) REFERENCES department(department_id)
);
GO

CREATE TABLE course_assignment (
    assignment_id   INT IDENTITY(1,1)   PRIMARY KEY,
    course_id       INT                 NOT NULL,
    semester_id     INT                 NOT NULL,
    staff_id        INT                 NOT NULL,
    CONSTRAINT fk_ca_course     FOREIGN KEY (course_id)   REFERENCES course(course_id),
    CONSTRAINT fk_ca_semester   FOREIGN KEY (semester_id) REFERENCES semester(semester_id),
    CONSTRAINT fk_ca_staff      FOREIGN KEY (staff_id)    REFERENCES staff(staff_id),
    CONSTRAINT uq_course_sem_staff UNIQUE (course_id, semester_id, staff_id)
);
GO

-- ============================================================
-- SECTION 9: DATA QUALITY LOG
-- Records all DQ check results before each ETL run
-- ============================================================

CREATE TABLE dq_check_log (
    check_id        INT IDENTITY(1,1)   PRIMARY KEY,
    check_name      NVARCHAR(200)       NOT NULL,
    check_category  NVARCHAR(50)        NOT NULL,  -- 'REGISTRATION','RESULTS','STUDENT','COURSE'
    severity        NVARCHAR(10)        NOT NULL,   -- 'ERROR','WARNING','INFO'
    records_flagged INT                 NOT NULL DEFAULT 0,
    detail          NVARCHAR(MAX),
    checked_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    etl_run_id      INT,                            -- links to etl_log in DW
    CONSTRAINT chk_dq_severity CHECK (severity IN ('ERROR','WARNING','INFO'))
);
GO

-- ============================================================
-- SECTION 10: OLTP VIEWS
-- ============================================================

CREATE OR ALTER VIEW vw_student_registration_summary AS
SELECT
    s.student_matric_no,
    CONCAT(s.first_name,' ',s.last_name)    AS student_name,
    sl.level_name                           AS current_level,
    p.programme_name,
    d.department_name,
    f.faculty_name,
    sem.semester_name,
    ac.session_name,
    sem.reg_deadline,
    COUNT(cr.registration_id)               AS total_courses_registered,
    SUM(c.credit_units)                     AS total_credit_units,
    CASE WHEN CAST(GETDATE() AS DATE) > sem.reg_deadline
         THEN 'Closed' ELSE 'Open' END      AS reg_window_status
FROM student s
JOIN student_level      sl  ON s.current_level_id   = sl.level_id
JOIN programme          p   ON s.programme_id        = p.programme_id
JOIN department         d   ON p.department_id       = d.department_id
JOIN faculty            f   ON d.faculty_id          = f.faculty_id
JOIN course_registration cr ON s.student_id          = cr.student_id
JOIN course             c   ON cr.course_id          = c.course_id
JOIN semester           sem ON cr.semester_id        = sem.semester_id
JOIN academic_session   ac  ON sem.session_id        = ac.session_id
WHERE sem.is_current = 1
GROUP BY s.student_id, s.student_matric_no, s.first_name, s.last_name,
         sl.level_name, p.programme_name, d.department_name, f.faculty_name,
         sem.semester_name, ac.session_name, sem.reg_deadline;
GO

CREATE OR ALTER VIEW vw_student_transcript AS
SELECT
    s.student_matric_no,
    CONCAT(s.first_name,' ',s.last_name)    AS student_name,
    ac.session_name,
    sem.semester_name,
    sl.level_name,
    c.course_code,
    c.course_title,
    c.credit_units,
    cr.course_type_taken,
    res.ca_score,
    res.exam_score,
    res.total_score,
    res.grade,
    res.grade_point,
    res.credit_units_earned,
    res.remark
FROM student s
JOIN course_registration cr ON s.student_id        = cr.student_id
JOIN course             c   ON cr.course_id        = c.course_id
JOIN semester           sem ON cr.semester_id      = sem.semester_id
JOIN academic_session   ac  ON sem.session_id      = ac.session_id
JOIN student_level      sl  ON c.level_id          = sl.level_id
LEFT JOIN course_result res ON cr.registration_id  = res.registration_id;
GO

CREATE OR ALTER VIEW vw_ser001_compliance AS
SELECT
    s.student_matric_no,
    CONCAT(s.first_name,' ',s.last_name)    AS student_name,
    sl.level_name,
    f.faculty_name,
    d.department_name,
    CASE WHEN cr.registration_id IS NOT NULL
         THEN 'Registered' ELSE 'NOT Registered' END AS ser001_status
FROM student s
JOIN student_level  sl  ON s.current_level_id = sl.level_id AND sl.level_number = 100
JOIN programme      p   ON s.programme_id     = p.programme_id
JOIN department     d   ON p.department_id    = d.department_id
JOIN faculty        f   ON d.faculty_id       = f.faculty_id
LEFT JOIN course_registration cr
    ON  s.student_id = cr.student_id
    AND cr.course_id = (SELECT TOP 1 course_id FROM course WHERE course_code = 'SER001');
GO

CREATE OR ALTER VIEW vw_course_prereq_chain AS
SELECT
    c.course_code           AS course_code,
    c.course_title          AS course_title,
    sl_c.level_name         AS course_level,
    pre.course_code         AS prerequisite_code,
    pre.course_title        AS prerequisite_title,
    sl_p.level_name         AS prereq_level,
    cp.min_grade            AS required_min_grade
FROM course_prerequisite cp
JOIN course         c    ON cp.course_id          = c.course_id
JOIN course         pre  ON cp.required_course_id = pre.course_id
JOIN student_level  sl_c ON c.level_id            = sl_c.level_id
JOIN student_level  sl_p ON pre.level_id          = sl_p.level_id;
GO

-- ============================================================
-- SECTION 11: STORED PROCEDURES
-- ============================================================

-- SP1: Register course with full business rule validation
CREATE OR ALTER PROCEDURE sp_register_course
    @p_student_id   INT,
    @p_course_id    INT,
    @p_semester_id  INT,
    @p_course_type  NVARCHAR(20),
    @p_result       NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_deadline     DATE;
    DECLARE @v_prereq_fail  INT;
    DECLARE @v_already_reg  INT;
    DECLARE @v_credit_load  INT;

    SELECT @v_deadline = reg_deadline FROM semester WHERE semester_id = @p_semester_id;
    IF @v_deadline IS NULL BEGIN SET @p_result = 'ERROR: Invalid semester.'; RETURN; END

    -- Rule 1: Deadline check
    IF CAST(GETDATE() AS DATE) > @v_deadline
    BEGIN
        INSERT INTO registration_audit (student_id, course_id, semester_id, was_late, rejection_reason)
        VALUES (@p_student_id, @p_course_id, @p_semester_id, 1, 'Registration deadline passed');
        SET @p_result = 'ERROR: Registration deadline has passed.';
        RETURN;
    END

    -- Rule 2: Duplicate check
    SELECT @v_already_reg = COUNT(*) FROM course_registration
    WHERE student_id = @p_student_id AND course_id = @p_course_id AND semester_id = @p_semester_id;
    IF @v_already_reg > 0 BEGIN SET @p_result = 'ERROR: Already registered for this course.'; RETURN; END

    -- Rule 3: Credit load check (max 24 units per semester)
    SELECT @v_credit_load = ISNULL(SUM(c.credit_units), 0)
    FROM course_registration cr JOIN course c ON cr.course_id = c.course_id
    WHERE cr.student_id = @p_student_id AND cr.semester_id = @p_semester_id;
    IF @v_credit_load + (SELECT credit_units FROM course WHERE course_id = @p_course_id) > 24
    BEGIN SET @p_result = 'ERROR: Registration would exceed 24 credit unit maximum.'; RETURN; END

    -- Rule 4: Prerequisite check
    SELECT @v_prereq_fail = COUNT(*)
    FROM course_prerequisite cp
    LEFT JOIN course_registration cr ON cr.course_id = cp.required_course_id AND cr.student_id = @p_student_id
    LEFT JOIN course_result res ON cr.registration_id = res.registration_id
    WHERE cp.course_id = @p_course_id
      AND (res.grade IS NULL OR res.grade > cp.min_grade);

    IF @v_prereq_fail > 0
    BEGIN
        INSERT INTO registration_audit (student_id, course_id, semester_id, was_late, prereqs_failed, rejection_reason)
        VALUES (@p_student_id, @p_course_id, @p_semester_id, 0, @v_prereq_fail, 'Prerequisites not satisfied');
        SET @p_result = CONCAT('ERROR: ', CAST(@v_prereq_fail AS NVARCHAR), ' prerequisite(s) not satisfied.');
        RETURN;
    END

    INSERT INTO course_registration (student_id, course_id, semester_id, course_type_taken)
    VALUES (@p_student_id, @p_course_id, @p_semester_id, @p_course_type);
    SET @p_result = 'SUCCESS: Course registered successfully.';
END;
GO

-- SP2: Promote student after session
CREATE OR ALTER PROCEDURE sp_promote_student
    @p_student_id   INT,
    @p_session_id   INT,
    @p_result       NVARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @v_level_num    INT;
    DECLARE @v_new_level_id INT;
    DECLARE @v_gpa          DECIMAL(4,2);
    DECLARE @v_credits      INT;

    SELECT @v_level_num = sl.level_number
    FROM student s JOIN student_level sl ON s.current_level_id = sl.level_id
    WHERE s.student_id = @p_student_id;

    SELECT @v_credits = SUM(res.credit_units_earned),
           @v_gpa = ROUND(SUM(res.grade_point * c.credit_units) / NULLIF(SUM(c.credit_units),0),2)
    FROM course_registration cr
    JOIN course c ON cr.course_id = c.course_id
    JOIN semester sem ON cr.semester_id = sem.semester_id
    JOIN course_result res ON cr.registration_id = res.registration_id
    WHERE cr.student_id = @p_student_id AND sem.session_id = @p_session_id;

    SELECT @v_new_level_id = level_id FROM student_level WHERE level_number = @v_level_num + 100;

    IF @v_new_level_id IS NULL
    BEGIN SET @p_result = 'INFO: Student at maximum level — eligible for graduation.'; RETURN; END

    UPDATE student SET current_level_id = @v_new_level_id, updated_at = GETDATE()
    WHERE student_id = @p_student_id;

    MERGE student_level_history AS tgt
    USING (SELECT @p_student_id, @p_session_id, @v_new_level_id, @v_gpa, @v_gpa, ISNULL(@v_credits,0)) AS src
        (student_id, session_id, level_id, gpa, cgpa, total_credits_earned)
    ON tgt.student_id = src.student_id AND tgt.session_id = src.session_id
    WHEN MATCHED THEN
        UPDATE SET level_id=src.level_id, gpa=src.gpa, cgpa=src.cgpa, total_credits_earned=src.total_credits_earned
    WHEN NOT MATCHED THEN
        INSERT (student_id, session_id, level_id, gpa, cgpa, total_credits_earned)
        VALUES (src.student_id, src.session_id, src.level_id, src.gpa, src.cgpa, src.total_credits_earned);

    SET @p_result = CONCAT('SUCCESS: Promoted to ', CAST(@v_level_num+100 AS NVARCHAR),'L. GPA: ', CAST(@v_gpa AS NVARCHAR));
END;
GO

-- SP3: Get student courses for a semester
CREATE OR ALTER PROCEDURE sp_get_student_courses
    @p_matric_no    NVARCHAR(30),
    @p_semester_id  INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT cr.course_type_taken, c.course_code, c.course_title,
           c.credit_units, cr.registration_status, cr.registration_date
    FROM student s
    JOIN course_registration cr ON s.student_id = cr.student_id
    JOIN course c ON cr.course_id = c.course_id
    WHERE s.student_matric_no = @p_matric_no AND cr.semester_id = @p_semester_id
    ORDER BY cr.course_type_taken, c.course_code;
END;
GO

-- SP4: Full transcript
CREATE OR ALTER PROCEDURE sp_get_transcript
    @p_matric_no NVARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM vw_student_transcript
    WHERE student_matric_no = @p_matric_no
    ORDER BY session_name, semester_name, course_code;
END;
GO

-- ============================================================
-- SECTION 12: ROW-LEVEL SECURITY
-- Restricts data access based on the database user's role.
--
-- Roles:
--   student_role   -> sees only their own rows
--   lecturer_role  -> sees only courses they are assigned to
--   faculty_admin  -> sees only their faculty's students
--   registry_admin -> sees everything (bypasses RLS)
-- ============================================================

-- Security context table (maps DB users to their entity ID)
CREATE TABLE security_user_map (
    db_username     NVARCHAR(100)   NOT NULL PRIMARY KEY,
    role_name       NVARCHAR(30)    NOT NULL,   -- 'student','lecturer','faculty_admin','registry_admin'
    entity_id       INT,                         -- student_id, staff_id, or faculty_id depending on role
    faculty_id      INT,
    CONSTRAINT chk_role CHECK (role_name IN ('student','lecturer','faculty_admin','registry_admin'))
);
GO

-- Inline table-valued function used by RLS policy
CREATE OR ALTER FUNCTION fn_rls_student_predicate(@student_id INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS rls_result
    WHERE
        -- Registry admins see everything
        EXISTS (
            SELECT 1 FROM dbo.security_user_map
            WHERE db_username = USER_NAME() AND role_name = 'registry_admin'
        )
        OR
        -- Students see only their own record
        EXISTS (
            SELECT 1 FROM dbo.security_user_map
            WHERE db_username = USER_NAME() AND role_name = 'student' AND entity_id = @student_id
        )
        OR
        -- Faculty admins see students in their faculty
        EXISTS (
            SELECT 1 FROM dbo.security_user_map m
            JOIN dbo.student s ON s.student_id = @student_id
            JOIN dbo.programme p ON s.programme_id = p.programme_id
            JOIN dbo.department d ON p.department_id = d.department_id
            WHERE m.db_username = USER_NAME() AND m.role_name = 'faculty_admin'
              AND d.faculty_id = m.faculty_id
        )
        OR
        -- Lecturers see students registered in their assigned courses
        EXISTS (
            SELECT 1 FROM dbo.security_user_map m
            JOIN dbo.course_assignment ca ON ca.staff_id = m.entity_id
            JOIN dbo.course_registration cr ON cr.course_id = ca.course_id
            WHERE m.db_username = USER_NAME() AND m.role_name = 'lecturer'
              AND cr.student_id = @student_id
        );
GO

-- Apply RLS policy to the student table
CREATE SECURITY POLICY rls_student_policy
    ADD FILTER PREDICATE dbo.fn_rls_student_predicate(student_id) ON dbo.student,
    ADD BLOCK  PREDICATE dbo.fn_rls_student_predicate(student_id) ON dbo.student
WITH (STATE = ON);
GO

-- ============================================================
-- SECTION 13: PERFORMANCE INDEXES
-- ============================================================
CREATE INDEX idx_student_programme      ON student(programme_id);
CREATE INDEX idx_student_level          ON student(current_level_id);
CREATE INDEX idx_student_status         ON student(enrollment_status);
CREATE INDEX idx_course_department      ON course(department_id);
CREATE INDEX idx_course_level           ON course(level_id);
CREATE INDEX idx_reg_student            ON course_registration(student_id);
CREATE INDEX idx_reg_course             ON course_registration(course_id);
CREATE INDEX idx_reg_semester           ON course_registration(semester_id);
CREATE INDEX idx_reg_updated            ON course_registration(updated_at);
CREATE INDEX idx_result_reg             ON course_result(registration_id);
CREATE INDEX idx_result_updated         ON course_result(updated_at);
CREATE INDEX idx_prog_course            ON programme_course(programme_id, course_id);
CREATE INDEX idx_semester_session       ON semester(session_id);
CREATE INDEX idx_dept_faculty           ON department(faculty_id);
GO

-- ============================================================
-- SECTION 14: EXTENDED PROPERTIES (Self-documenting metadata)
-- Query with: SELECT * FROM sys.extended_properties
-- ============================================================
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'OLTP source of truth for all university academic operations. Do NOT run analytical queries directly against this database — use luxuniversity_dw instead.',
    @level0type=N'Schema', @level0name=N'dbo';
GO
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'Stores all student enrolment records. System-versioned temporal table — full history is available in dbo.student_history. Protected by Row-Level Security policy rls_student_policy.',
    @level0type=N'Schema', @level0name=N'dbo', @level1type=N'Table', @level1name=N'student';
GO
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'Watermark table for incremental ETL. The ETL job reads last_extracted_at per entity and only moves rows with updated_at > last_extracted_at.',
    @level0type=N'Schema', @level0name=N'dbo', @level1type=N'Table', @level1name=N'etl_watermark';
GO
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'One row per course registration. Unique on (student_id, course_id, semester_id). sp_register_course enforces deadline, credit load, and prerequisite rules before inserting here.',
    @level0type=N'Schema', @level0name=N'dbo', @level1type=N'Table', @level1name=N'course_registration';
GO
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'SER001 is_compulsory_se=1. Mapped to every programme as COMPULSORY_SE. All 100L students must register this regardless of department. Monitored by vw_ser001_compliance.',
    @level0type=N'Schema', @level0name=N'dbo', @level1type=N'Table', @level1name=N'course';
GO

-- ============================================================
-- END OF 01_create_oltp.sql
-- ============================================================

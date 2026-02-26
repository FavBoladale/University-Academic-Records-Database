-- ============================================================
-- LuxUniversity DW
-- FILE: 02_create_dw.sql
-- PURPOSE: Create the Data Warehouse (OLAP) database
-- ENGINE: Microsoft SQL Server 2016+ / Azure SQL Database
-- ============================================================
-- Separate database from luxuniversity_db (the OLTP source).
-- Populated by 04_etl_incremental.sql on a scheduled basis.
-- Uses CLUSTERED COLUMNSTORE INDEXES on fact tables for
-- 10-100x faster analytical query performance.
-- ============================================================

USE master;
GO

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'luxuniversity_dw')
BEGIN
    ALTER DATABASE luxuniversity_dw SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE luxuniversity_dw;
END
GO

CREATE DATABASE luxuniversity_dw COLLATE Latin1_General_CI_AS;
GO

USE luxuniversity_dw;
GO

-- ============================================================
-- SECTION 1: ETL LOG
-- Every ETL run is recorded here for monitoring and debugging.
-- ============================================================
CREATE TABLE etl_log (
    etl_run_id          INT IDENTITY(1,1)   PRIMARY KEY,
    run_started_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    run_finished_at     DATETIME2,
    status              NVARCHAR(20)        NOT NULL DEFAULT 'RUNNING', -- RUNNING, SUCCESS, FAILED
    rows_inserted       INT                 NOT NULL DEFAULT 0,
    rows_updated        INT                 NOT NULL DEFAULT 0,
    scd2_rows_closed    INT                 NOT NULL DEFAULT 0,
    dq_errors           INT                 NOT NULL DEFAULT 0,
    dq_warnings         INT                 NOT NULL DEFAULT 0,
    error_message       NVARCHAR(MAX),
    triggered_by        NVARCHAR(100)       NOT NULL DEFAULT SYSTEM_USER,
    CONSTRAINT chk_etl_status CHECK (status IN ('RUNNING','SUCCESS','FAILED','PARTIAL'))
);
GO

-- ============================================================
-- SECTION 2: DIMENSION TABLES
-- All dimensions use surrogate keys (SK) separate from the
-- natural keys (ID) from the OLTP system.
-- ============================================================

-- DIM: Date (static, pre-populated for 2021-2030)
CREATE TABLE dim_date (
    date_key        INT             NOT NULL PRIMARY KEY,   -- YYYYMMDD integer key
    full_date       DATE            NOT NULL UNIQUE,
    day_name        NVARCHAR(15)    NOT NULL,
    day_num         INT             NOT NULL,               -- 1-31
    week_num        INT             NOT NULL,               -- ISO week number
    month_num       INT             NOT NULL,               -- 1-12
    month_name      NVARCHAR(15)    NOT NULL,
    quarter_num     INT             NOT NULL,               -- 1-4
    quarter_name    NVARCHAR(5)     NOT NULL,               -- Q1-Q4
    year_num        INT             NOT NULL,
    academic_year   NVARCHAR(10),                           -- e.g. '2024/2025'
    academic_week   INT,                                    -- week within academic year
    is_weekend      BIT             NOT NULL DEFAULT 0,
    is_holiday      BIT             NOT NULL DEFAULT 0,
    season          NVARCHAR(20)                            -- 'First Semester','Second Semester','Vacation'
);
GO

-- DIM: Student (Type 2 SCD — full history preserved)
-- When a student changes programme or level, the ETL:
--   1. Closes the current row (is_current=0, expiry_date=today)
--   2. Inserts a new row (is_current=1, effective_date=today)
-- This lets you ask: "What was this student's faculty in 2022?"
CREATE TABLE dim_student (
    student_sk          INT IDENTITY(1,1)   PRIMARY KEY,   -- surrogate key
    student_id          INT                 NOT NULL,       -- OLTP natural key
    student_matric_no   NVARCHAR(30)        NOT NULL,
    full_name           NVARCHAR(300)       NOT NULL,
    first_name          NVARCHAR(100),
    last_name           NVARCHAR(100),
    gender              NVARCHAR(10),
    state_of_origin     NVARCHAR(80),
    programme_name      NVARCHAR(250),
    faculty_name        NVARCHAR(200),
    department_name     NVARCHAR(200),
    level_name          NVARCHAR(10),
    level_number        INT,
    degree_type         NVARCHAR(15),
    admission_year      NVARCHAR(10),
    enrollment_status   NVARCHAR(20),
    -- SCD2 tracking columns
    effective_date      DATE                NOT NULL,
    expiry_date         DATE                NOT NULL DEFAULT '9999-12-31',
    is_current          BIT                 NOT NULL DEFAULT 1,
    dw_created_at       DATETIME2           NOT NULL DEFAULT GETDATE(),
    dw_updated_at       DATETIME2           NOT NULL DEFAULT GETDATE(),
    etl_run_id          INT
);
GO

CREATE INDEX idx_dim_student_id      ON dim_student(student_id);
CREATE INDEX idx_dim_student_current ON dim_student(student_id, is_current);
CREATE INDEX idx_dim_student_matric  ON dim_student(student_matric_no);
GO

-- DIM: Course (Type 1 SCD — overwrite on change)
CREATE TABLE dim_course (
    course_sk           INT IDENTITY(1,1)   PRIMARY KEY,
    course_id           INT                 NOT NULL UNIQUE,
    course_code         NVARCHAR(15)        NOT NULL,
    course_title        NVARCHAR(300)       NOT NULL,
    course_description  NVARCHAR(MAX),
    credit_units        INT                 NOT NULL,
    category_code       NVARCHAR(25),
    category_name       NVARCHAR(100),
    department_name     NVARCHAR(200),
    faculty_name        NVARCHAR(200),
    faculty_abbreviation NVARCHAR(25),
    level_name          NVARCHAR(10),
    level_number        INT,
    semester_offered    NVARCHAR(10),
    is_compulsory_se    BIT                 NOT NULL DEFAULT 0,
    is_active           BIT                 NOT NULL DEFAULT 1,
    has_prerequisites   BIT                 NOT NULL DEFAULT 0,
    prerequisite_count  INT                 NOT NULL DEFAULT 0,
    dw_created_at       DATETIME2           NOT NULL DEFAULT GETDATE(),
    dw_updated_at       DATETIME2           NOT NULL DEFAULT GETDATE()
);
GO

-- DIM: Academic Period
CREATE TABLE dim_academic_period (
    period_sk           INT IDENTITY(1,1)   PRIMARY KEY,
    semester_id         INT                 NOT NULL UNIQUE,
    session_name        NVARCHAR(20)        NOT NULL,
    semester_name       NVARCHAR(10)        NOT NULL,
    full_period_name    AS (session_name + ' - ' + semester_name + ' Semester') PERSISTED,
    academic_year       INT                 NOT NULL,
    start_date          DATE                NOT NULL,
    end_date            DATE                NOT NULL,
    reg_deadline        DATE                NOT NULL,
    reg_duration_days   AS (DATEDIFF(DAY, start_date, reg_deadline)) PERSISTED,
    semester_duration_days AS (DATEDIFF(DAY, start_date, end_date)) PERSISTED,
    is_current          BIT                 NOT NULL DEFAULT 0
);
GO

-- DIM: Staff (for lecturer performance analysis)
CREATE TABLE dim_staff (
    staff_sk            INT IDENTITY(1,1)   PRIMARY KEY,
    staff_id            INT                 NOT NULL UNIQUE,
    staff_no            NVARCHAR(30),
    full_name           NVARCHAR(200),
    department_name     NVARCHAR(200),
    faculty_name        NVARCHAR(200),
    designation         NVARCHAR(100),
    is_active           BIT                 NOT NULL DEFAULT 1,
    dw_created_at       DATETIME2           NOT NULL DEFAULT GETDATE()
);
GO

-- DIM: Geography (student origins for demographic analytics)
CREATE TABLE dim_geography (
    geo_sk          INT IDENTITY(1,1)   PRIMARY KEY,
    state_name      NVARCHAR(80)        NOT NULL UNIQUE,
    geopolitical_zone NVARCHAR(50),     -- North-West, South-West, etc.
    region          NVARCHAR(30)        -- North, South
);
GO

-- Pre-populate Nigerian states
INSERT INTO dim_geography (state_name, geopolitical_zone, region) VALUES
('Abia','South-East','South'),('Adamawa','North-East','North'),
('Akwa Ibom','South-South','South'),('Anambra','South-East','South'),
('Bauchi','North-East','North'),('Bayelsa','South-South','South'),
('Benue','North-Central','North'),('Borno','North-East','North'),
('Cross River','South-South','South'),('Delta','South-South','South'),
('Ebonyi','South-East','South'),('Edo','South-South','South'),
('Ekiti','South-West','South'),('Enugu','South-East','South'),
('FCT','North-Central','North'),('Gombe','North-East','North'),
('Imo','South-East','South'),('Jigawa','North-West','North'),
('Kaduna','North-West','North'),('Kano','North-West','North'),
('Katsina','North-West','North'),('Kebbi','North-West','North'),
('Kogi','North-Central','North'),('Kwara','North-Central','North'),
('Lagos','South-West','South'),('Nasarawa','North-Central','North'),
('Niger','North-Central','North'),('Ogun','South-West','South'),
('Ondo','South-West','South'),('Osun','South-West','South'),
('Oyo','South-West','South'),('Plateau','North-Central','North'),
('Rivers','South-South','South'),('Sokoto','North-West','North'),
('Taraba','North-East','North'),('Yobe','North-East','North'),
('Zamfara','North-West','North');
GO

-- ============================================================
-- SECTION 3: FACT TABLES WITH COLUMNSTORE INDEXES
-- Columnstore indexes compress data column-by-column and enable
-- batch-mode execution — analytical aggregations run 10-100x
-- faster than row-store on large datasets.
-- ============================================================

-- FACT: Enrollment & Results (central fact table)
-- Grain: one row per (student, course, semester)
CREATE TABLE fact_enrollment (
    enrollment_fact_id  INT IDENTITY(1,1)   NOT NULL,
    -- Dimension keys
    student_sk          INT                 NOT NULL,
    course_sk           INT                 NOT NULL,
    period_sk           INT                 NOT NULL,
    staff_sk            INT,                                -- lecturer for the course
    geo_sk              INT,                                -- student's state of origin
    reg_date_key        INT,                                -- registration date key
    result_date_key     INT,                                -- result entry date key
    -- OLTP natural key (for lineage/debugging)
    registration_id     INT                 NOT NULL,
    -- Degenerate dimensions
    course_type_taken   NVARCHAR(20),
    registration_status NVARCHAR(20),
    -- Measures
    ca_score            DECIMAL(5,2),
    exam_score          DECIMAL(5,2),
    total_score         DECIMAL(5,2),
    grade               NVARCHAR(5),
    grade_point         DECIMAL(3,1),
    credit_units        INT                 NOT NULL DEFAULT 0,
    credit_units_earned INT                 NOT NULL DEFAULT 0,
    -- Calculated boolean flags (makes slice-and-dice simple)
    is_pass             BIT                 NOT NULL DEFAULT 0,
    is_distinction      BIT                 NOT NULL DEFAULT 0,  -- grade A
    is_credit           BIT                 NOT NULL DEFAULT 0,  -- grade B
    is_fail             BIT                 NOT NULL DEFAULT 0,
    is_absent           BIT                 NOT NULL DEFAULT 0,
    is_late_registration BIT               NOT NULL DEFAULT 0,
    is_major_course     BIT                 NOT NULL DEFAULT 0,
    is_elective_course  BIT                 NOT NULL DEFAULT 0,
    is_compulsory_se    BIT                 NOT NULL DEFAULT 0,
    -- ETL metadata
    dw_inserted_at      DATETIME2           NOT NULL DEFAULT GETDATE(),
    etl_run_id          INT,
    CONSTRAINT pk_fact_enrollment PRIMARY KEY NONCLUSTERED (enrollment_fact_id),
    CONSTRAINT fk_fe_student FOREIGN KEY (student_sk) REFERENCES dim_student(student_sk),
    CONSTRAINT fk_fe_course  FOREIGN KEY (course_sk)  REFERENCES dim_course(course_sk),
    CONSTRAINT fk_fe_period  FOREIGN KEY (period_sk)  REFERENCES dim_academic_period(period_sk)
);

-- Clustered columnstore index — replaces default clustered rowstore
-- This compresses data by column and enables batch mode execution
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_enrollment ON fact_enrollment;
GO

-- FACT: Student GPA per session (aggregate fact table)
-- Grain: one row per (student, session)
CREATE TABLE fact_student_gpa (
    gpa_fact_id             INT IDENTITY(1,1)   NOT NULL,
    student_sk              INT                 NOT NULL,
    period_sk               INT                 NOT NULL,
    geo_sk                  INT,
    -- Measures
    session_gpa             DECIMAL(4,2),
    cgpa                    DECIMAL(4,2),
    total_credits_attempted INT                 NOT NULL DEFAULT 0,
    total_credits_earned    INT                 NOT NULL DEFAULT 0,
    courses_registered      INT                 NOT NULL DEFAULT 0,
    courses_passed          INT                 NOT NULL DEFAULT 0,
    courses_failed          INT                 NOT NULL DEFAULT 0,
    courses_absent          INT                 NOT NULL DEFAULT 0,
    -- Academic standing flags
    is_first_class          BIT                 NOT NULL DEFAULT 0,  -- CGPA >= 4.5
    is_second_class_upper   BIT                 NOT NULL DEFAULT 0,  -- CGPA 3.5-4.49
    is_second_class_lower   BIT                 NOT NULL DEFAULT 0,  -- CGPA 2.4-3.49
    is_third_class          BIT                 NOT NULL DEFAULT 0,  -- CGPA 1.5-2.39
    is_at_risk              BIT                 NOT NULL DEFAULT 0,  -- CGPA < 1.5
    -- ETL metadata
    dw_inserted_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    etl_run_id              INT,
    CONSTRAINT pk_fact_gpa PRIMARY KEY NONCLUSTERED (gpa_fact_id),
    CONSTRAINT fk_gpa_student FOREIGN KEY (student_sk) REFERENCES dim_student(student_sk),
    CONSTRAINT fk_gpa_period  FOREIGN KEY (period_sk)  REFERENCES dim_academic_period(period_sk)
);

CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_student_gpa ON fact_student_gpa;
GO

-- FACT: Registration events (compliance and behaviour analysis)
-- Grain: one row per registration attempt (including rejected)
CREATE TABLE fact_registration_event (
    reg_event_id            INT IDENTITY(1,1)   NOT NULL,
    student_sk              INT                 NOT NULL,
    course_sk               INT                 NOT NULL,
    period_sk               INT                 NOT NULL,
    attempt_date_key        INT,
    -- Measures
    days_from_sem_start     INT,                            -- how many days after semester start
    days_before_deadline    INT,                            -- negative = registered late
    was_late                BIT                 NOT NULL DEFAULT 0,
    was_rejected            BIT                 NOT NULL DEFAULT 0,
    prereqs_failed          INT                 NOT NULL DEFAULT 0,
    registration_status     NVARCHAR(20),
    rejection_reason        NVARCHAR(500),
    -- ETL metadata
    dw_inserted_at          DATETIME2           NOT NULL DEFAULT GETDATE(),
    etl_run_id              INT,
    CONSTRAINT pk_reg_event PRIMARY KEY NONCLUSTERED (reg_event_id),
    CONSTRAINT fk_re_student FOREIGN KEY (student_sk) REFERENCES dim_student(student_sk),
    CONSTRAINT fk_re_course  FOREIGN KEY (course_sk)  REFERENCES dim_course(course_sk),
    CONSTRAINT fk_re_period  FOREIGN KEY (period_sk)  REFERENCES dim_academic_period(period_sk)
);

CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_reg_event ON fact_registration_event;
GO

-- ============================================================
-- SECTION 4: REPORTING LAYER (rpt schema)
-- Pre-built KPI views for university management dashboards.
-- All views query fact/dim tables — never the OLTP source.
-- ============================================================

CREATE SCHEMA rpt;
GO

-- RPT 1: Faculty performance dashboard
CREATE OR ALTER VIEW rpt.vw_faculty_performance AS
SELECT
    ds.faculty_name,
    dp.session_name,
    dp.semester_name,
    COUNT(DISTINCT fe.student_sk)                                   AS total_students,
    COUNT(fe.enrollment_fact_id)                                    AS total_enrollments,
    ROUND(AVG(CAST(fe.total_score  AS FLOAT)), 1)                   AS avg_total_score,
    ROUND(AVG(CAST(fe.grade_point  AS FLOAT)), 2)                   AS avg_grade_point,
    SUM(CAST(fe.is_pass            AS INT))                         AS total_passes,
    SUM(CAST(fe.is_fail            AS INT))                         AS total_failures,
    SUM(CAST(fe.is_distinction     AS INT))                         AS total_distinctions,
    ROUND(100.0 * SUM(CAST(fe.is_pass AS INT))
          / NULLIF(COUNT(fe.enrollment_fact_id),0), 1)              AS pass_rate_pct,
    ROUND(100.0 * SUM(CAST(fe.is_fail AS INT))
          / NULLIF(COUNT(fe.enrollment_fact_id),0), 1)              AS failure_rate_pct,
    ROUND(100.0 * SUM(CAST(fe.is_distinction AS INT))
          / NULLIF(COUNT(fe.enrollment_fact_id),0), 1)              AS distinction_rate_pct
FROM fact_enrollment fe
JOIN dim_student        ds  ON fe.student_sk = ds.student_sk
JOIN dim_academic_period dp  ON fe.period_sk  = dp.period_sk
WHERE ds.is_current = 1
GROUP BY ds.faculty_name, dp.session_name, dp.semester_name;
GO

-- RPT 2: At-risk students (CGPA < 1.5 or multiple failures)
CREATE OR ALTER VIEW rpt.vw_at_risk_students AS
SELECT
    ds.student_matric_no,
    ds.full_name,
    ds.faculty_name,
    ds.department_name,
    ds.programme_name,
    ds.level_name,
    fg.cgpa,
    fg.courses_failed,
    fg.courses_registered,
    fg.total_credits_earned,
    CASE
        WHEN fg.cgpa < 1.5          THEN 'Critical — Probation Risk'
        WHEN fg.cgpa < 2.4          THEN 'Warning — Third Class Range'
        WHEN fg.courses_failed >= 3 THEN 'Warning — Multiple Failures'
        ELSE 'Monitor'
    END AS risk_level,
    dp.session_name AS latest_session
FROM fact_student_gpa fg
JOIN dim_student         ds ON fg.student_sk = ds.student_sk AND ds.is_current = 1
JOIN dim_academic_period dp ON fg.period_sk  = dp.period_sk
WHERE fg.is_at_risk = 1
   OR fg.courses_failed >= 3
   OR fg.cgpa < 2.4;
GO

-- RPT 3: SER001 compliance rate by faculty
CREATE OR ALTER VIEW rpt.vw_ser001_compliance_rate AS
SELECT
    ds.faculty_name,
    dp.session_name,
    COUNT(DISTINCT ds.student_sk)                                   AS total_100L_students,
    SUM(CAST(fe.is_compulsory_se   AS INT))                         AS ser001_registered,
    COUNT(DISTINCT ds.student_sk)
        - COUNT(DISTINCT CASE WHEN fe.is_compulsory_se = 1
                              THEN ds.student_sk END)               AS ser001_missing,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN fe.is_compulsory_se = 1
                                      THEN ds.student_sk END)
          / NULLIF(COUNT(DISTINCT ds.student_sk),0), 1)             AS compliance_rate_pct
FROM dim_student ds
JOIN dim_academic_period dp ON 1=1
LEFT JOIN fact_enrollment fe
    ON  fe.student_sk       = ds.student_sk
    AND fe.period_sk        = dp.period_sk
    AND fe.is_compulsory_se = 1
WHERE ds.level_name = '100L' AND ds.is_current = 1
GROUP BY ds.faculty_name, dp.session_name;
GO

-- RPT 4: Course failure rate (flags curriculum issues)
CREATE OR ALTER VIEW rpt.vw_course_failure_rate AS
SELECT
    dc.course_code,
    dc.course_title,
    dc.faculty_name,
    dc.department_name,
    dc.level_name,
    dc.credit_units,
    dp.session_name,
    dp.semester_name,
    COUNT(fe.enrollment_fact_id)                                    AS total_enrolled,
    SUM(CAST(fe.is_pass AS INT))                                    AS passed,
    SUM(CAST(fe.is_fail AS INT))                                    AS failed,
    ROUND(100.0 * SUM(CAST(fe.is_fail AS INT))
          / NULLIF(COUNT(fe.enrollment_fact_id),0), 1)              AS failure_rate_pct,
    ROUND(AVG(CAST(fe.total_score AS FLOAT)), 1)                    AS avg_score,
    CASE
        WHEN 100.0 * SUM(CAST(fe.is_fail AS INT))
             / NULLIF(COUNT(fe.enrollment_fact_id),0) > 40 THEN 'HIGH RISK'
        WHEN 100.0 * SUM(CAST(fe.is_fail AS INT))
             / NULLIF(COUNT(fe.enrollment_fact_id),0) > 25 THEN 'ELEVATED'
        ELSE 'NORMAL'
    END AS risk_flag
FROM fact_enrollment fe
JOIN dim_course          dc ON fe.course_sk = dc.course_sk
JOIN dim_academic_period dp ON fe.period_sk  = dp.period_sk
GROUP BY dc.course_sk, dc.course_code, dc.course_title, dc.faculty_name,
         dc.department_name, dc.level_name, dc.credit_units,
         dp.session_name, dp.semester_name
HAVING COUNT(fe.enrollment_fact_id) >= 5;
GO

-- RPT 5: Registration behaviour (early vs late, by faculty)
CREATE OR ALTER VIEW rpt.vw_registration_behaviour AS
SELECT
    ds.faculty_name,
    ds.level_name,
    dp.session_name,
    dp.semester_name,
    COUNT(re.reg_event_id)                                          AS total_registrations,
    SUM(CAST(re.was_late AS INT))                                   AS late_registrations,
    SUM(CAST(re.was_rejected AS INT))                               AS rejected_registrations,
    ROUND(AVG(CAST(re.days_before_deadline AS FLOAT)), 1)           AS avg_days_before_deadline,
    ROUND(100.0 * SUM(CAST(re.was_late AS INT))
          / NULLIF(COUNT(re.reg_event_id),0), 1)                    AS late_rate_pct
FROM fact_registration_event re
JOIN dim_student         ds ON re.student_sk = ds.student_sk AND ds.is_current = 1
JOIN dim_academic_period dp ON re.period_sk  = dp.period_sk
GROUP BY ds.faculty_name, ds.level_name, dp.session_name, dp.semester_name;
GO

-- RPT 6: Credit load distribution
CREATE OR ALTER VIEW rpt.vw_credit_load_distribution AS
SELECT
    ds.faculty_name,
    ds.level_name,
    dp.session_name,
    dp.semester_name,
    COUNT(DISTINCT fe.student_sk)                                   AS students,
    MIN(SUM(fe.credit_units)) OVER (PARTITION BY ds.faculty_name,
        ds.level_name, dp.period_sk)                                AS min_credits,
    MAX(SUM(fe.credit_units)) OVER (PARTITION BY ds.faculty_name,
        ds.level_name, dp.period_sk)                                AS max_credits,
    ROUND(AVG(SUM(fe.credit_units)) OVER (PARTITION BY ds.faculty_name,
        ds.level_name, dp.period_sk), 1)                            AS avg_credits
FROM fact_enrollment fe
JOIN dim_student         ds ON fe.student_sk = ds.student_sk AND ds.is_current = 1
JOIN dim_academic_period dp ON fe.period_sk  = dp.period_sk
GROUP BY ds.student_sk, ds.faculty_name, ds.level_name, dp.period_sk,
         dp.session_name, dp.semester_name;
GO

-- RPT 7: Geopolitical diversity report
CREATE OR ALTER VIEW rpt.vw_student_diversity AS
SELECT
    dg.geopolitical_zone,
    dg.region,
    ds.faculty_name,
    dp.session_name,
    COUNT(DISTINCT fe.student_sk)                                   AS student_count,
    ROUND(AVG(CAST(fg.cgpa AS FLOAT)), 2)                           AS avg_cgpa
FROM fact_enrollment fe
JOIN dim_student         ds ON fe.student_sk = ds.student_sk AND ds.is_current = 1
JOIN dim_geography       dg ON fe.geo_sk     = dg.geo_sk
JOIN dim_academic_period dp ON fe.period_sk  = dp.period_sk
LEFT JOIN fact_student_gpa fg ON fg.student_sk = fe.student_sk AND fg.period_sk = fe.period_sk
GROUP BY dg.geopolitical_zone, dg.region, ds.faculty_name, dp.session_name;
GO

-- ============================================================
-- SECTION 5: DW INDEXES (non-clustered, on top of columnstore)
-- These support specific point-lookups while the columnstore
-- handles full-table analytical scans.
-- ============================================================
CREATE INDEX idx_dim_course_code     ON dim_course(course_code);
CREATE INDEX idx_dim_course_faculty  ON dim_course(faculty_name);
CREATE INDEX idx_dim_period_session  ON dim_academic_period(session_name, semester_name);
CREATE INDEX idx_dim_staff_id        ON dim_staff(staff_id);
CREATE INDEX idx_date_year_month     ON dim_date(year_num, month_num);
GO

-- ============================================================
-- SECTION 6: EXTENDED PROPERTIES
-- ============================================================
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'LuxUniversity Data Warehouse. Read-only analytical database populated by incremental ETL from luxuniversity_db. Use rpt.* views for dashboards and reporting.',
    @level0type=N'Schema', @level0name=N'dbo';
GO
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'Type 2 Slowly Changing Dimension. When student changes programme/level the ETL closes old row (is_current=0, expiry_date=today) and inserts new row. Enables historical analysis.',
    @level0type=N'Schema', @level0name=N'dbo', @level1type=N'Table', @level1name=N'dim_student';
GO
EXEC sp_addextendedproperty @name=N'MS_Description',
    @value=N'Central fact table. Grain: one row per (student, course, semester). Clustered columnstore index for 10-100x faster analytical aggregations. Contains pre-computed boolean flags for simple slicing.',
    @level0type=N'Schema', @level0name=N'dbo', @level1type=N'Table', @level1name=N'fact_enrollment';
GO

-- ============================================================
-- END OF 02_create_dw.sql
-- ============================================================

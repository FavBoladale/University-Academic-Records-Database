-- ============================================================
-- LuxUniversity DW
-- FILE: 06_reporting_layer.sql
-- PURPOSE: Extended reporting views for management dashboards
-- RUN AFTER: 02_create_dw.sql, 04_etl_incremental.sql
-- ============================================================
-- All views live in the [rpt] schema in luxuniversity_dw.
-- Query these — never the OLTP database — for reporting.
-- ============================================================

USE luxuniversity_dw;
GO

-- ============================================================
-- RPT 1: Faculty Performance (already in 02_create_dw.sql)
-- ============================================================

-- ============================================================
-- RPT 2: Department-level GPA league table
-- Shows every department ranked by average CGPA
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_department_gpa_ranking AS
WITH dept_stats AS (
    SELECT
        ds.faculty_name,
        ds.department_name,
        dp.session_name,
        ROUND(AVG(CAST(fg.session_gpa AS FLOAT)), 2)  AS avg_session_gpa,
        ROUND(AVG(CAST(fg.cgpa AS FLOAT)), 2)          AS avg_cgpa,
        COUNT(DISTINCT fg.student_sk)                  AS student_count,
        SUM(CAST(fg.is_first_class AS INT))            AS first_class_count,
        SUM(CAST(fg.is_second_class_upper AS INT))     AS sc_upper_count,
        SUM(CAST(fg.is_at_risk AS INT))                AS at_risk_count
    FROM fact_student_gpa fg
    JOIN dim_student         ds ON fg.student_sk = ds.student_sk AND ds.is_current = 1
    JOIN dim_academic_period dp ON fg.period_sk  = dp.period_sk
    GROUP BY ds.faculty_name, ds.department_name, dp.session_name
)
SELECT
    faculty_name,
    department_name,
    session_name,
    avg_session_gpa,
    avg_cgpa,
    student_count,
    first_class_count,
    sc_upper_count,
    at_risk_count,
    ROUND(100.0 * first_class_count / NULLIF(student_count,0), 1) AS first_class_pct,
    RANK() OVER (PARTITION BY session_name ORDER BY avg_cgpa DESC) AS cgpa_rank
FROM dept_stats;
GO

-- ============================================================
-- RPT 3: Student academic progression tracking
-- Shows CGPA trend across all sessions for each student
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_student_progression AS
SELECT
    ds.student_matric_no,
    ds.full_name,
    ds.faculty_name,
    ds.programme_name,
    dp.session_name,
    dp.semester_name,
    fg.session_gpa,
    fg.cgpa,
    -- CGPA change from previous session
    fg.cgpa - LAG(fg.cgpa) OVER (
        PARTITION BY ds.student_id
        ORDER BY dp.academic_year, dp.semester_name
    ) AS cgpa_delta,
    fg.courses_registered,
    fg.courses_passed,
    fg.courses_failed,
    fg.total_credits_earned,
    CASE
        WHEN fg.cgpa >= 4.50 THEN '1st Class'
        WHEN fg.cgpa >= 3.50 THEN '2nd Class Upper'
        WHEN fg.cgpa >= 2.40 THEN '2nd Class Lower'
        WHEN fg.cgpa >= 1.50 THEN '3rd Class'
        ELSE 'Pass / Probation'
    END AS class_of_degree,
    fg.is_at_risk
FROM fact_student_gpa fg
JOIN dim_student         ds ON fg.student_sk = ds.student_sk AND ds.is_current = 1
JOIN dim_academic_period dp ON fg.period_sk  = dp.period_sk;
GO

-- ============================================================
-- RPT 4: Prerequisite compliance — who shouldn't have been registered
-- Identifies registrations where prerequisites were not met
-- (for audit and academic integrity purposes)
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_prereq_compliance_audit AS
SELECT
    ds.student_matric_no,
    ds.full_name,
    ds.faculty_name,
    dc_main.course_code         AS registered_course,
    dc_main.course_title        AS registered_title,
    dc_pre.course_code          AS missing_prereq_code,
    dc_pre.course_title         AS missing_prereq_title,
    dp.session_name,
    dp.semester_name,
    fe.registration_status
FROM fact_enrollment fe
JOIN dim_student         ds      ON fe.student_sk    = ds.student_sk AND ds.is_current = 1
JOIN dim_course          dc_main ON fe.course_sk     = dc_main.course_sk
JOIN dim_academic_period dp      ON fe.period_sk     = dp.period_sk
-- Find courses that have prerequisites
JOIN luxuniversity_db.dbo.course_prerequisite cp
    ON dc_main.course_id = cp.course_id
JOIN dim_course          dc_pre  ON cp.required_course_id = dc_pre.course_id
-- Check if the student passed the prerequisite before this registration
WHERE NOT EXISTS (
    SELECT 1
    FROM luxuniversity_db.dbo.course_registration cr_pre
    JOIN luxuniversity_db.dbo.course_result       res_pre ON cr_pre.registration_id = res_pre.registration_id
    JOIN luxuniversity_db.dbo.semester            sem_pre ON cr_pre.semester_id     = sem_pre.semester_id
    JOIN luxuniversity_db.dbo.semester            sem_cur ON fe.period_sk = (
        SELECT period_sk FROM dim_academic_period dap WHERE dap.semester_id = sem_cur.semester_id
    )
    WHERE cr_pre.student_id   = ds.student_id
      AND cr_pre.course_id    = cp.required_course_id
      AND res_pre.grade      <= cp.min_grade
      AND sem_pre.start_date  < sem_cur.start_date
);
GO

-- ============================================================
-- RPT 5: Semester registration timeline
-- How registration volume builds up day by day
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_registration_timeline AS
SELECT
    dp.session_name,
    dp.semester_name,
    dd.full_date                    AS registration_date,
    dd.day_name,
    DATEDIFF(DAY, dp.start_date, dd.full_date) AS day_of_semester,
    DATEDIFF(DAY, dd.full_date, dp.reg_deadline) AS days_until_deadline,
    COUNT(re.reg_event_id)          AS daily_registrations,
    SUM(COUNT(re.reg_event_id)) OVER (
        PARTITION BY dp.period_sk
        ORDER BY dd.full_date
    )                               AS cumulative_registrations,
    SUM(CAST(re.was_late AS INT))   AS late_registrations,
    SUM(CAST(re.was_rejected AS INT)) AS rejected_attempts
FROM fact_registration_event re
JOIN dim_academic_period dp ON re.period_sk       = dp.period_sk
JOIN dim_date            dd ON re.attempt_date_key = dd.date_key
GROUP BY dp.session_name, dp.semester_name, dp.period_sk,
         dp.start_date, dp.reg_deadline, dd.full_date, dd.day_name;
GO

-- ============================================================
-- RPT 6: Lecturer course load and student performance
-- Shows how many students each lecturer taught and avg scores
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_lecturer_performance AS
SELECT
    dst.full_name               AS lecturer_name,
    dst.department_name,
    dst.faculty_name,
    dst.designation,
    dp.session_name,
    dp.semester_name,
    dc.course_code,
    dc.course_title,
    dc.level_name,
    dc.credit_units,
    COUNT(fe.enrollment_fact_id)                AS students_enrolled,
    ROUND(AVG(CAST(fe.total_score AS FLOAT)),1) AS avg_score,
    ROUND(AVG(CAST(fe.grade_point AS FLOAT)),2) AS avg_grade_point,
    SUM(CAST(fe.is_pass AS INT))                AS students_passed,
    SUM(CAST(fe.is_fail AS INT))                AS students_failed,
    SUM(CAST(fe.is_distinction AS INT))         AS distinctions,
    ROUND(100.0 * SUM(CAST(fe.is_pass AS INT))
          / NULLIF(COUNT(fe.enrollment_fact_id),0), 1) AS pass_rate_pct
FROM fact_enrollment fe
JOIN dim_staff           dst ON fe.staff_sk   = dst.staff_sk
JOIN dim_course          dc  ON fe.course_sk  = dc.course_sk
JOIN dim_academic_period dp  ON fe.period_sk  = dp.period_sk
GROUP BY dst.staff_sk, dst.full_name, dst.department_name, dst.faculty_name,
         dst.designation, dp.session_name, dp.semester_name,
         dc.course_sk, dc.course_code, dc.course_title, dc.level_name, dc.credit_units;
GO

-- ============================================================
-- RPT 7: Credit unit completion rate by faculty and level
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_credit_completion_rate AS
SELECT
    ds.faculty_name,
    ds.level_name,
    dp.session_name,
    COUNT(DISTINCT fg.student_sk)           AS students,
    SUM(fg.total_credits_attempted)         AS total_credits_attempted,
    SUM(fg.total_credits_earned)            AS total_credits_earned,
    ROUND(100.0 * SUM(fg.total_credits_earned)
          / NULLIF(SUM(fg.total_credits_attempted),0), 1) AS completion_rate_pct,
    ROUND(AVG(CAST(fg.session_gpa AS FLOAT)), 2) AS avg_gpa
FROM fact_student_gpa fg
JOIN dim_student         ds ON fg.student_sk = ds.student_sk AND ds.is_current = 1
JOIN dim_academic_period dp ON fg.period_sk  = dp.period_sk
GROUP BY ds.faculty_name, ds.level_name, dp.session_name;
GO

-- ============================================================
-- RPT 8: ETL health dashboard
-- For monitoring the data pipeline
-- ============================================================
CREATE OR ALTER VIEW rpt.vw_etl_health AS
SELECT
    etl_run_id,
    run_started_at,
    run_finished_at,
    status,
    DATEDIFF(SECOND, run_started_at, run_finished_at) AS duration_seconds,
    rows_inserted,
    rows_updated,
    scd2_rows_closed,
    dq_errors,
    dq_warnings,
    triggered_by,
    CASE
        WHEN status = 'SUCCESS' AND dq_warnings = 0 THEN 'Healthy'
        WHEN status = 'SUCCESS' AND dq_warnings > 0  THEN 'Healthy with Warnings'
        WHEN status = 'PARTIAL'                       THEN 'Partial — Check Logs'
        WHEN status = 'FAILED'                        THEN 'FAILED — Action Required'
        ELSE 'Unknown'
    END AS health_status,
    error_message
FROM etl_log;
GO

-- ============================================================
-- SAMPLE ANALYTICAL QUERIES AGAINST THE REPORTING LAYER
-- ============================================================

-- Faculty performance for latest session:
-- SELECT * FROM rpt.vw_faculty_performance
-- WHERE session_name = (SELECT TOP 1 session_name FROM dim_academic_period ORDER BY academic_year DESC)
-- ORDER BY avg_grade_point DESC;

-- Students at risk right now:
-- SELECT * FROM rpt.vw_at_risk_students WHERE risk_level = 'Critical — Probation Risk';

-- Department GPA league table for current year:
-- SELECT TOP 10 * FROM rpt.vw_department_gpa_ranking
-- WHERE session_name = '2024/2025' ORDER BY cgpa_rank;

-- Student CGPA trend (individual):
-- SELECT * FROM rpt.vw_student_progression
-- WHERE student_matric_no = 'CST/2022/001'
-- ORDER BY session_name;

-- Courses with alarmingly high failure rates:
-- SELECT * FROM rpt.vw_course_failure_rate
-- WHERE failure_rate_pct > 30 ORDER BY failure_rate_pct DESC;

-- Registration volume by day (current semester):
-- SELECT * FROM rpt.vw_registration_timeline
-- WHERE session_name='2024/2025' AND semester_name='Second'
-- ORDER BY registration_date;

-- ETL health check:
-- SELECT TOP 10 * FROM rpt.vw_etl_health ORDER BY etl_run_id DESC;

-- ============================================================
-- END OF 06_reporting_layer.sql
-- ============================================================

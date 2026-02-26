-- ============================================================
-- LuxUniversity DW
-- FILE: 04_etl_incremental.sql
-- PURPOSE: Incremental ETL from luxuniversity_db (OLTP)
--          into luxuniversity_dw (Data Warehouse)
-- ============================================================
-- HOW IT WORKS:
--   1. Reads last_extracted_at from luxuniversity_db.etl_watermark
--   2. Extracts only rows WHERE updated_at > last_extracted_at
--   3. Applies SCD Type 2 logic on dim_student
--   4. Loads fact tables with pre-computed boolean flags
--   5. Updates watermark timestamps on success
--   6. Logs every run to luxuniversity_dw.etl_log
--
-- SCHEDULING: Run via SQL Server Agent on a daily/hourly job.
-- CROSS-DB:   Requires both databases on the same SQL Server
--             instance, OR use Linked Server for remote sources.
-- ============================================================

USE luxuniversity_dw;
GO

-- ============================================================
-- ETL SCHEMA
-- Separates ETL internals from the rpt reporting layer.
-- Must be created before any etl.* procedures below.
-- ============================================================
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'etl')
    EXEC('CREATE SCHEMA etl');
GO

-- ============================================================
-- MASTER ETL PROCEDURE
-- Entry point — call this from SQL Server Agent or manually.
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_run_incremental_etl
    @p_force_full_reload BIT = 0   -- set 1 to ignore watermark and reload everything
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @v_run_id       INT;
    DECLARE @v_rows_ins     INT = 0;
    DECLARE @v_rows_upd     INT = 0;
    DECLARE @v_scd2_closed  INT = 0;
    DECLARE @v_dq_errors    INT = 0;
    DECLARE @v_dq_warnings  INT = 0;
    DECLARE @v_error_msg    NVARCHAR(MAX);
    DECLARE @v_today        DATE = CAST(GETDATE() AS DATE);

    -- Watermark timestamps (read from OLTP)
    DECLARE @wm_student         DATETIME2;
    DECLARE @wm_course          DATETIME2;
    DECLARE @wm_registration    DATETIME2;
    DECLARE @wm_result          DATETIME2;
    DECLARE @wm_session         DATETIME2;
    DECLARE @wm_semester        DATETIME2;
    DECLARE @wm_staff           DATETIME2;

    -- ── Open ETL log entry ──────────────────────────────────
    INSERT INTO etl_log (run_started_at, status, triggered_by)
    VALUES (GETDATE(), 'RUNNING', SYSTEM_USER);
    SET @v_run_id = SCOPE_IDENTITY();

    BEGIN TRY

        -- ── Step 0: Run data quality checks ─────────────────
        EXEC etl.sp_run_dq_checks @p_etl_run_id = @v_run_id,
             @p_errors   = @v_dq_errors   OUTPUT,
             @p_warnings = @v_dq_warnings OUTPUT;

        IF @v_dq_errors > 0
        BEGIN
            UPDATE etl_log SET status='FAILED', run_finished_at=GETDATE(),
                dq_errors=@v_dq_errors, dq_warnings=@v_dq_warnings,
                error_message=CONCAT(@v_dq_errors,' DQ errors blocked ETL. Check luxuniversity_db.dq_check_log.')
            WHERE etl_run_id = @v_run_id;
            RAISERROR('ETL aborted: %d data quality errors found. Review dq_check_log.', 16, 1, @v_dq_errors);
            RETURN;
        END

        -- ── Step 1: Read watermarks ──────────────────────────
        IF @p_force_full_reload = 1
        BEGIN
            SELECT @wm_student='1900-01-01', @wm_course='1900-01-01',
                   @wm_registration='1900-01-01', @wm_result='1900-01-01',
                   @wm_session='1900-01-01', @wm_semester='1900-01-01',
                   @wm_staff='1900-01-01';
        END
        ELSE
        BEGIN
            SELECT @wm_student      = MAX(CASE WHEN entity_name='student'              THEN last_extracted_at END),
                   @wm_course       = MAX(CASE WHEN entity_name='course'               THEN last_extracted_at END),
                   @wm_registration = MAX(CASE WHEN entity_name='course_registration'  THEN last_extracted_at END),
                   @wm_result       = MAX(CASE WHEN entity_name='course_result'        THEN last_extracted_at END),
                   @wm_session      = MAX(CASE WHEN entity_name='academic_session'     THEN last_extracted_at END),
                   @wm_semester     = MAX(CASE WHEN entity_name='semester'             THEN last_extracted_at END),
                   @wm_staff        = MAX(CASE WHEN entity_name='staff'                THEN last_extracted_at END)
            FROM luxuniversity_db.dbo.etl_watermark;
        END

        -- ── Step 2: Populate dim_date (idempotent) ───────────
        EXEC etl.sp_load_dim_date @p_etl_run_id = @v_run_id;

        -- ── Step 3: Load dimension tables ────────────────────
        EXEC etl.sp_load_dim_academic_period @p_watermark=@wm_semester,  @p_etl_run_id=@v_run_id, @p_rows_inserted=@v_rows_ins OUTPUT;
        EXEC etl.sp_load_dim_course          @p_watermark=@wm_course,    @p_etl_run_id=@v_run_id, @p_rows_inserted=@v_rows_ins OUTPUT;
        EXEC etl.sp_load_dim_staff           @p_watermark=@wm_staff,     @p_etl_run_id=@v_run_id, @p_rows_inserted=@v_rows_ins OUTPUT;

        -- SCD2 student dimension (most complex)
        EXEC etl.sp_load_dim_student_scd2    @p_watermark=@wm_student,   @p_etl_run_id=@v_run_id,
             @p_rows_inserted=@v_rows_ins OUTPUT,
             @p_rows_updated =@v_rows_upd OUTPUT,
             @p_scd2_closed  =@v_scd2_closed OUTPUT;

        -- ── Step 4: Load fact tables ──────────────────────────
        EXEC etl.sp_load_fact_enrollment     @p_watermark=@wm_result,       @p_etl_run_id=@v_run_id, @p_rows_inserted=@v_rows_ins OUTPUT;
        EXEC etl.sp_load_fact_student_gpa    @p_watermark=@wm_result,       @p_etl_run_id=@v_run_id, @p_rows_inserted=@v_rows_ins OUTPUT;
        EXEC etl.sp_load_fact_reg_events     @p_watermark=@wm_registration, @p_etl_run_id=@v_run_id, @p_rows_inserted=@v_rows_ins OUTPUT;

        -- ── Step 5: Update watermarks in OLTP ────────────────
        UPDATE luxuniversity_db.dbo.etl_watermark
        SET last_extracted_at = GETDATE(), updated_at = GETDATE()
        WHERE entity_name IN (
            'student','course','course_registration','course_result',
            'academic_session','semester','staff'
        );

        -- ── Step 6: Close ETL log as SUCCESS ─────────────────
        UPDATE etl_log
        SET status='SUCCESS', run_finished_at=GETDATE(),
            rows_inserted   = @v_rows_ins,
            rows_updated    = @v_rows_upd,
            scd2_rows_closed= @v_scd2_closed,
            dq_errors       = @v_dq_errors,
            dq_warnings     = @v_dq_warnings
        WHERE etl_run_id = @v_run_id;

    END TRY
    BEGIN CATCH
        SET @v_error_msg = CONCAT(
            'Error ', ERROR_NUMBER(), ' in ', ERROR_PROCEDURE(),
            ' line ', ERROR_LINE(), ': ', ERROR_MESSAGE()
        );
        UPDATE etl_log
        SET status='FAILED', run_finished_at=GETDATE(),
            error_message=@v_error_msg,
            dq_errors=@v_dq_errors, dq_warnings=@v_dq_warnings
        WHERE etl_run_id = @v_run_id;
        THROW;
    END CATCH
END;
GO

-- ============================================================
-- SP: Load dim_date (idempotent — safe to run repeatedly)
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_dim_date
    @p_etl_run_id INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Only generate dates that don't already exist
    WITH DateRange AS (
        SELECT CAST('2021-01-01' AS DATE) AS d
        UNION ALL
        SELECT DATEADD(DAY,1,d) FROM DateRange WHERE d < '2030-12-31'
    )
    INSERT INTO dim_date (
        date_key, full_date, day_name, day_num, week_num, month_num,
        month_name, quarter_num, quarter_name, year_num, academic_year,
        is_weekend, season
    )
    SELECT
        CAST(FORMAT(d,'yyyyMMdd') AS INT),
        d,
        DATENAME(WEEKDAY,d),
        DAY(d),
        DATEPART(ISO_WEEK,d),
        MONTH(d),
        DATENAME(MONTH,d),
        DATEPART(QUARTER,d),
        CONCAT('Q',DATEPART(QUARTER,d)),
        YEAR(d),
        -- Academic year: Sep-Aug cycle
        CASE WHEN MONTH(d) >= 9
             THEN CONCAT(YEAR(d),'/',YEAR(d)+1)
             ELSE CONCAT(YEAR(d)-1,'/',YEAR(d))
        END,
        CASE WHEN DATEPART(WEEKDAY,d) IN (1,7) THEN 1 ELSE 0 END,
        CASE
            WHEN MONTH(d) IN (9,10,11,12,1)  THEN 'First Semester'
            WHEN MONTH(d) IN (2,3,4,5,6)     THEN 'Second Semester'
            ELSE 'Vacation'
        END
    FROM DateRange
    WHERE NOT EXISTS (
        SELECT 1 FROM dim_date dd
        WHERE dd.date_key = CAST(FORMAT(d,'yyyyMMdd') AS INT)
    )
    OPTION (MAXRECURSION 5000);
END;
GO

-- ============================================================
-- SP: Load dim_academic_period
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_dim_academic_period
    @p_watermark    DATETIME2,
    @p_etl_run_id   INT,
    @p_rows_inserted INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;

    MERGE dim_academic_period AS tgt
    USING (
        SELECT sem.semester_id, ac.session_name, sem.semester_name,
               YEAR(sem.start_date) AS academic_year,
               sem.start_date, sem.end_date, sem.reg_deadline, sem.is_current
        FROM luxuniversity_db.dbo.semester sem
        JOIN luxuniversity_db.dbo.academic_session ac ON sem.session_id = ac.session_id
        WHERE sem.updated_at > @p_watermark
    ) AS src ON tgt.semester_id = src.semester_id
    WHEN MATCHED THEN UPDATE SET
        session_name   = src.session_name,
        semester_name  = src.semester_name,
        academic_year  = src.academic_year,
        start_date     = src.start_date,
        end_date       = src.end_date,
        reg_deadline   = src.reg_deadline,
        is_current     = src.is_current
    WHEN NOT MATCHED THEN INSERT
        (semester_id, session_name, semester_name, academic_year,
         start_date, end_date, reg_deadline, is_current)
    VALUES
        (src.semester_id, src.session_name, src.semester_name, src.academic_year,
         src.start_date, src.end_date, src.reg_deadline, src.is_current);

    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Load dim_course (Type 1 SCD — overwrite on change)
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_dim_course
    @p_watermark    DATETIME2,
    @p_etl_run_id   INT,
    @p_rows_inserted INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;

    MERGE dim_course AS tgt
    USING (
        SELECT
            c.course_id, c.course_code, c.course_title, c.course_description,
            c.credit_units, cc.category_code, cc.category_name,
            d.department_name, f.faculty_name, f.abbreviation AS faculty_abbreviation,
            sl.level_name, sl.level_number, c.semester_offered,
            c.is_compulsory_se, c.is_active,
            CAST(CASE WHEN EXISTS (
                SELECT 1 FROM luxuniversity_db.dbo.course_prerequisite cp
                WHERE cp.course_id = c.course_id
            ) THEN 1 ELSE 0 END AS BIT) AS has_prerequisites,
            (SELECT COUNT(*) FROM luxuniversity_db.dbo.course_prerequisite cp
             WHERE cp.course_id = c.course_id) AS prerequisite_count
        FROM luxuniversity_db.dbo.course c
        JOIN luxuniversity_db.dbo.course_category cc ON c.category_id    = cc.category_id
        JOIN luxuniversity_db.dbo.department       d  ON c.department_id  = d.department_id
        JOIN luxuniversity_db.dbo.faculty          f  ON d.faculty_id     = f.faculty_id
        JOIN luxuniversity_db.dbo.student_level    sl ON c.level_id       = sl.level_id
        WHERE c.updated_at > @p_watermark
    ) AS src ON tgt.course_id = src.course_id
    WHEN MATCHED THEN UPDATE SET
        course_code=src.course_code, course_title=src.course_title,
        course_description=src.course_description, credit_units=src.credit_units,
        category_code=src.category_code, category_name=src.category_name,
        department_name=src.department_name, faculty_name=src.faculty_name,
        faculty_abbreviation=src.faculty_abbreviation, level_name=src.level_name,
        level_number=src.level_number, semester_offered=src.semester_offered,
        is_compulsory_se=src.is_compulsory_se, is_active=src.is_active,
        has_prerequisites=src.has_prerequisites, prerequisite_count=src.prerequisite_count,
        dw_updated_at=GETDATE()
    WHEN NOT MATCHED THEN INSERT
        (course_id, course_code, course_title, course_description, credit_units,
         category_code, category_name, department_name, faculty_name, faculty_abbreviation,
         level_name, level_number, semester_offered, is_compulsory_se, is_active,
         has_prerequisites, prerequisite_count)
    VALUES
        (src.course_id, src.course_code, src.course_title, src.course_description, src.credit_units,
         src.category_code, src.category_name, src.department_name, src.faculty_name, src.faculty_abbreviation,
         src.level_name, src.level_number, src.semester_offered, src.is_compulsory_se, src.is_active,
         src.has_prerequisites, src.prerequisite_count);

    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Load dim_staff (Type 1 SCD)
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_dim_staff
    @p_watermark    DATETIME2,
    @p_etl_run_id   INT,
    @p_rows_inserted INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;

    MERGE dim_staff AS tgt
    USING (
        SELECT s.staff_id, s.staff_no,
               CONCAT(s.first_name,' ',s.last_name) AS full_name,
               d.department_name, f.faculty_name, s.designation, s.is_active
        FROM luxuniversity_db.dbo.staff s
        JOIN luxuniversity_db.dbo.department d ON s.department_id = d.department_id
        JOIN luxuniversity_db.dbo.faculty    f ON d.faculty_id    = f.faculty_id
        WHERE s.updated_at > @p_watermark
    ) AS src ON tgt.staff_id = src.staff_id
    WHEN MATCHED THEN UPDATE SET
        full_name=src.full_name, department_name=src.department_name,
        faculty_name=src.faculty_name, designation=src.designation, is_active=src.is_active
    WHEN NOT MATCHED THEN INSERT
        (staff_id, staff_no, full_name, department_name, faculty_name, designation, is_active)
    VALUES
        (src.staff_id, src.staff_no, src.full_name, src.department_name,
         src.faculty_name, src.designation, src.is_active);

    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Load dim_student with SCD Type 2
--
-- SCD2 LOGIC:
--   Changed rows: close current row (expiry_date=today, is_current=0)
--                 insert new row    (effective_date=today, is_current=1)
--   New rows:     insert directly
--   Unchanged:    skip
--
-- CHANGE DETECTION: Compares programme_name, level_name,
--   faculty_name, department_name, enrollment_status
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_dim_student_scd2
    @p_watermark        DATETIME2,
    @p_etl_run_id       INT,
    @p_rows_inserted    INT OUTPUT,
    @p_rows_updated     INT OUTPUT,
    @p_scd2_closed      INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;
    SET @p_rows_updated  = 0;
    SET @p_scd2_closed   = 0;

    DECLARE @v_today DATE = CAST(GETDATE() AS DATE);

    -- Staging CTE: current snapshot from OLTP
    WITH oltp_snapshot AS (
        SELECT
            s.student_id,
            s.student_matric_no,
            CONCAT(s.first_name,' ',s.last_name)    AS full_name,
            s.first_name, s.last_name,
            s.gender, s.state_of_origin,
            p.programme_name,
            f.faculty_name,
            d.department_name,
            sl.level_name,
            sl.level_number,
            dt.degree_code                          AS degree_type,
            ac.session_name                         AS admission_year,
            s.enrollment_status,
            s.updated_at
        FROM luxuniversity_db.dbo.student           s
        JOIN luxuniversity_db.dbo.programme         p  ON s.programme_id       = p.programme_id
        JOIN luxuniversity_db.dbo.department        d  ON p.department_id      = d.department_id
        JOIN luxuniversity_db.dbo.faculty           f  ON d.faculty_id         = f.faculty_id
        JOIN luxuniversity_db.dbo.student_level     sl ON s.current_level_id   = sl.level_id
        JOIN luxuniversity_db.dbo.degree_type       dt ON p.degree_type_id     = dt.degree_type_id
        JOIN luxuniversity_db.dbo.academic_session  ac ON s.admission_session_id = ac.session_id
        WHERE s.updated_at > @p_watermark
    ),
    -- Detect which existing dim rows have changed SCD2 attributes
    changed_students AS (
        SELECT src.student_id
        FROM oltp_snapshot src
        JOIN dim_student tgt ON src.student_id = tgt.student_id AND tgt.is_current = 1
        WHERE src.programme_name    <> tgt.programme_name
           OR src.level_name        <> tgt.level_name
           OR src.faculty_name      <> tgt.faculty_name
           OR src.department_name   <> tgt.department_name
           OR src.enrollment_status <> tgt.enrollment_status
    )

    -- Step A: Close old rows for changed students
    UPDATE dim_student
    SET is_current   = 0,
        expiry_date  = @v_today,
        dw_updated_at= GETDATE()
    WHERE student_id IN (SELECT student_id FROM changed_students)
      AND is_current = 1;
    SET @p_scd2_closed = @@ROWCOUNT;

    -- Step B: Insert new rows for changed students (new version)
    INSERT INTO dim_student (
        student_id, student_matric_no, full_name, first_name, last_name,
        gender, state_of_origin, programme_name, faculty_name, department_name,
        level_name, level_number, degree_type, admission_year, enrollment_status,
        effective_date, expiry_date, is_current, etl_run_id
    )
    SELECT
        src.student_id, src.student_matric_no, src.full_name, src.first_name, src.last_name,
        src.gender, src.state_of_origin, src.programme_name, src.faculty_name, src.department_name,
        src.level_name, src.level_number, src.degree_type, src.admission_year, src.enrollment_status,
        @v_today, '9999-12-31', 1, @p_etl_run_id
    FROM oltp_snapshot src
    WHERE src.student_id IN (SELECT student_id FROM changed_students);
    SET @p_rows_updated = @@ROWCOUNT;

    -- Step C: Insert brand new students (never seen before)
    INSERT INTO dim_student (
        student_id, student_matric_no, full_name, first_name, last_name,
        gender, state_of_origin, programme_name, faculty_name, department_name,
        level_name, level_number, degree_type, admission_year, enrollment_status,
        effective_date, expiry_date, is_current, etl_run_id
    )
    SELECT
        src.student_id, src.student_matric_no, src.full_name, src.first_name, src.last_name,
        src.gender, src.state_of_origin, src.programme_name, src.faculty_name, src.department_name,
        src.level_name, src.level_number, src.degree_type, src.admission_year, src.enrollment_status,
        @v_today, '9999-12-31', 1, @p_etl_run_id
    FROM oltp_snapshot src
    WHERE NOT EXISTS (
        SELECT 1 FROM dim_student ds WHERE ds.student_id = src.student_id
    );
    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Load fact_enrollment (incremental by result.updated_at)
-- Late-arriving facts: results entered after semester end are
-- still loaded — we never reject late facts, just load them.
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_fact_enrollment
    @p_watermark    DATETIME2,
    @p_etl_run_id   INT,
    @p_rows_inserted INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;

    -- Delete and re-insert changed registrations (simpler than MERGE on columnstore)
    DELETE fe
    FROM fact_enrollment fe
    WHERE fe.registration_id IN (
        SELECT cr.registration_id
        FROM luxuniversity_db.dbo.course_result res
        JOIN luxuniversity_db.dbo.course_registration cr
            ON res.registration_id = cr.registration_id
        WHERE res.updated_at > @p_watermark
    );

    INSERT INTO fact_enrollment (
        student_sk, course_sk, period_sk, staff_sk, geo_sk,
        reg_date_key, result_date_key, registration_id,
        course_type_taken, registration_status,
        ca_score, exam_score, total_score, grade, grade_point,
        credit_units, credit_units_earned,
        is_pass, is_distinction, is_credit, is_fail, is_absent,
        is_late_registration, is_major_course, is_elective_course, is_compulsory_se,
        etl_run_id
    )
    SELECT
        ds.student_sk,
        dc.course_sk,
        dap.period_sk,
        dsta.staff_sk,
        dg.geo_sk,
        CAST(FORMAT(CAST(cr.registration_date AS DATE),'yyyyMMdd') AS INT),
        CAST(FORMAT(CAST(res.entered_at AS DATE),'yyyyMMdd') AS INT),
        cr.registration_id,
        cr.course_type_taken,
        cr.registration_status,
        res.ca_score, res.exam_score, res.total_score,
        res.grade, res.grade_point,
        c.credit_units, res.credit_units_earned,
        -- Boolean flags (pre-computed for fast slicing)
        CASE WHEN res.remark = 'Pass'   THEN 1 ELSE 0 END,
        CASE WHEN res.grade  = 'A'      THEN 1 ELSE 0 END,
        CASE WHEN res.grade  = 'B'      THEN 1 ELSE 0 END,
        CASE WHEN res.remark = 'Fail'   THEN 1 ELSE 0 END,
        CASE WHEN res.remark = 'Absent' THEN 1 ELSE 0 END,
        CASE WHEN CAST(cr.registration_date AS DATE) > sem.reg_deadline THEN 1 ELSE 0 END,
        CASE WHEN cr.course_type_taken = 'MAJOR'         THEN 1 ELSE 0 END,
        CASE WHEN cr.course_type_taken = 'ELECTIVE'      THEN 1 ELSE 0 END,
        CASE WHEN cr.course_type_taken = 'COMPULSORY_SE' THEN 1 ELSE 0 END,
        @p_etl_run_id
    FROM luxuniversity_db.dbo.course_result         res
    JOIN luxuniversity_db.dbo.course_registration   cr  ON res.registration_id = cr.registration_id
    JOIN luxuniversity_db.dbo.course                c   ON cr.course_id        = c.course_id
    JOIN luxuniversity_db.dbo.semester              sem ON cr.semester_id      = sem.semester_id
    -- DW dimension lookups
    JOIN dim_student        ds  ON cr.student_id  = ds.student_id   AND ds.is_current = 1
    JOIN dim_course         dc  ON cr.course_id   = dc.course_id
    JOIN dim_academic_period dap ON cr.semester_id = dap.semester_id
    -- Optional dimensions (LEFT JOIN — may not always have a match)
    LEFT JOIN luxuniversity_db.dbo.course_assignment ca_asgn
        ON ca_asgn.course_id = cr.course_id AND ca_asgn.semester_id = cr.semester_id
    LEFT JOIN dim_staff     dsta ON ca_asgn.staff_id = dsta.staff_id
    LEFT JOIN luxuniversity_db.dbo.student s_src ON cr.student_id = s_src.student_id
    LEFT JOIN dim_geography dg ON s_src.state_of_origin = dg.state_name
    WHERE res.updated_at > @p_watermark;

    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Load fact_student_gpa (recalculates affected students)
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_fact_student_gpa
    @p_watermark    DATETIME2,
    @p_etl_run_id   INT,
    @p_rows_inserted INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;

    -- Identify students with new/changed results
    DELETE fg
    FROM fact_student_gpa fg
    WHERE fg.student_sk IN (
        SELECT DISTINCT ds.student_sk
        FROM luxuniversity_db.dbo.course_result res
        JOIN luxuniversity_db.dbo.course_registration cr ON res.registration_id = cr.registration_id
        JOIN dim_student ds ON cr.student_id = ds.student_id AND ds.is_current = 1
        WHERE res.updated_at > @p_watermark
    );

    -- Recalculate and insert GPA facts per student per session
    WITH session_results AS (
        SELECT
            cr.student_id,
            sem.session_id,
            SUM(c.credit_units)                                         AS credits_attempted,
            SUM(res.credit_units_earned)                                AS credits_earned,
            COUNT(cr.registration_id)                                   AS courses_registered,
            SUM(CASE WHEN res.remark='Pass'   THEN 1 ELSE 0 END)        AS courses_passed,
            SUM(CASE WHEN res.remark='Fail'   THEN 1 ELSE 0 END)        AS courses_failed,
            SUM(CASE WHEN res.remark='Absent' THEN 1 ELSE 0 END)        AS courses_absent,
            ROUND(SUM(res.grade_point * c.credit_units)
                  / NULLIF(SUM(c.credit_units),0), 2)                   AS session_gpa
        FROM luxuniversity_db.dbo.course_registration cr
        JOIN luxuniversity_db.dbo.course_result       res ON cr.registration_id = res.registration_id
        JOIN luxuniversity_db.dbo.course              c   ON cr.course_id       = c.course_id
        JOIN luxuniversity_db.dbo.semester            sem ON cr.semester_id     = sem.semester_id
        GROUP BY cr.student_id, sem.session_id
    ),
    -- Compute rolling CGPA across all sessions up to each point
    cgpa_calc AS (
        SELECT
            student_id, session_id, session_gpa,
            credits_attempted, credits_earned,
            courses_registered, courses_passed, courses_failed, courses_absent,
            ROUND(SUM(session_gpa) OVER (
                PARTITION BY student_id ORDER BY session_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ) / COUNT(*) OVER (
                PARTITION BY student_id ORDER BY session_id
                ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
            ), 2) AS cgpa
        FROM session_results
    )
    INSERT INTO fact_student_gpa (
        student_sk, period_sk, geo_sk, session_gpa, cgpa,
        total_credits_attempted, total_credits_earned,
        courses_registered, courses_passed, courses_failed, courses_absent,
        is_first_class, is_second_class_upper, is_second_class_lower,
        is_third_class, is_at_risk, etl_run_id
    )
    SELECT
        ds.student_sk,
        dap.period_sk,
        dg.geo_sk,
        cc.session_gpa, cc.cgpa,
        cc.credits_attempted, cc.credits_earned,
        cc.courses_registered, cc.courses_passed, cc.courses_failed, cc.courses_absent,
        CASE WHEN cc.cgpa >= 4.50 THEN 1 ELSE 0 END,
        CASE WHEN cc.cgpa BETWEEN 3.50 AND 4.49 THEN 1 ELSE 0 END,
        CASE WHEN cc.cgpa BETWEEN 2.40 AND 3.49 THEN 1 ELSE 0 END,
        CASE WHEN cc.cgpa BETWEEN 1.50 AND 2.39 THEN 1 ELSE 0 END,
        CASE WHEN cc.cgpa < 1.50 THEN 1 ELSE 0 END,
        @p_etl_run_id
    FROM cgpa_calc cc
    JOIN luxuniversity_db.dbo.semester    sem ON cc.session_id  = sem.session_id AND sem.semester_name = 'Second'
    JOIN dim_student                      ds  ON cc.student_id  = ds.student_id  AND ds.is_current = 1
    JOIN dim_academic_period              dap ON sem.semester_id = dap.semester_id
    LEFT JOIN luxuniversity_db.dbo.student s_src ON cc.student_id = s_src.student_id
    LEFT JOIN dim_geography               dg  ON s_src.state_of_origin = dg.state_name;

    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Load fact_registration_event
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_load_fact_reg_events
    @p_watermark    DATETIME2,
    @p_etl_run_id   INT,
    @p_rows_inserted INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_rows_inserted = 0;

    -- Insert new registration events (successful registrations)
    INSERT INTO fact_registration_event (
        student_sk, course_sk, period_sk, attempt_date_key,
        days_from_sem_start, days_before_deadline,
        was_late, was_rejected, prereqs_failed, registration_status,
        etl_run_id
    )
    SELECT
        ds.student_sk, dc.course_sk, dap.period_sk,
        CAST(FORMAT(CAST(cr.registration_date AS DATE),'yyyyMMdd') AS INT),
        DATEDIFF(DAY, sem.start_date, CAST(cr.registration_date AS DATE)),
        DATEDIFF(DAY, CAST(cr.registration_date AS DATE), sem.reg_deadline),
        CASE WHEN CAST(cr.registration_date AS DATE) > sem.reg_deadline THEN 1 ELSE 0 END,
        0, 0,
        cr.registration_status,
        @p_etl_run_id
    FROM luxuniversity_db.dbo.course_registration cr
    JOIN luxuniversity_db.dbo.semester           sem ON cr.semester_id = sem.semester_id
    JOIN dim_student        ds  ON cr.student_id  = ds.student_id  AND ds.is_current = 1
    JOIN dim_course         dc  ON cr.course_id   = dc.course_id
    JOIN dim_academic_period dap ON cr.semester_id = dap.semester_id
    WHERE cr.updated_at > @p_watermark
      AND NOT EXISTS (
          SELECT 1 FROM fact_registration_event fre
          WHERE fre.student_sk = ds.student_sk
            AND fre.course_sk  = dc.course_sk
            AND fre.period_sk  = dap.period_sk
            AND fre.was_rejected = 0
      );

    -- Also capture rejected/audit attempts
    INSERT INTO fact_registration_event (
        student_sk, course_sk, period_sk, attempt_date_key,
        days_from_sem_start, days_before_deadline,
        was_late, was_rejected, prereqs_failed, registration_status, rejection_reason,
        etl_run_id
    )
    SELECT
        ds.student_sk, dc.course_sk, dap.period_sk,
        CAST(FORMAT(CAST(ra.attempt_time AS DATE),'yyyyMMdd') AS INT),
        DATEDIFF(DAY, sem.start_date, CAST(ra.attempt_time AS DATE)),
        DATEDIFF(DAY, CAST(ra.attempt_time AS DATE), sem.reg_deadline),
        ra.was_late, 1, ra.prereqs_failed,
        'Rejected', ra.rejection_reason,
        @p_etl_run_id
    FROM luxuniversity_db.dbo.registration_audit ra
    JOIN luxuniversity_db.dbo.semester           sem ON ra.semester_id = sem.semester_id
    JOIN dim_student        ds  ON ra.student_id  = ds.student_id  AND ds.is_current = 1
    JOIN dim_course         dc  ON ra.course_id   = dc.course_id
    JOIN dim_academic_period dap ON ra.semester_id = dap.semester_id
    WHERE ra.attempt_time > @p_watermark;

    SET @p_rows_inserted = @@ROWCOUNT;
END;
GO

-- ============================================================
-- SP: Data Quality Checks (run before ETL loads)
-- All failures logged to luxuniversity_db.dq_check_log
-- ETL is BLOCKED if any ERROR severity checks fail.
-- ============================================================
CREATE OR ALTER PROCEDURE etl.sp_run_dq_checks
    @p_etl_run_id   INT,
    @p_errors       INT OUTPUT,
    @p_warnings     INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @p_errors   = 0;
    SET @p_warnings = 0;

    DECLARE @v_count INT;
    DECLARE @v_detail NVARCHAR(MAX);

    -- ── DQ-01: Students with no programme assigned ────────
    SELECT @v_count = COUNT(*) FROM luxuniversity_db.dbo.student
    WHERE programme_id IS NULL;
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Students with NULL programme_id','STUDENT','ERROR',@v_count,
                CONCAT(@v_count,' students have no programme assigned.'), @p_etl_run_id);
        SET @p_errors += 1;
    END

    -- ── DQ-02: Results with impossible total score (>100) ─
    SELECT @v_count = COUNT(*) FROM luxuniversity_db.dbo.course_result
    WHERE total_score > 100;
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Results with total_score > 100','RESULTS','ERROR',@v_count,
                CONCAT(@v_count,' results have total_score exceeding 100.'), @p_etl_run_id);
        SET @p_errors += 1;
    END

    -- ── DQ-03: Registrations after semester end date ──────
    SELECT @v_count = COUNT(*)
    FROM luxuniversity_db.dbo.course_registration cr
    JOIN luxuniversity_db.dbo.semester sem ON cr.semester_id = sem.semester_id
    WHERE CAST(cr.registration_date AS DATE) > sem.end_date;
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Registrations after semester end date','REGISTRATION','WARNING',@v_count,
                CONCAT(@v_count,' registrations have dates after semester end.'), @p_etl_run_id);
        SET @p_warnings += 1;
    END

    -- ── DQ-04: 100L students without SER001 registration ─
    SELECT @v_count = COUNT(*)
    FROM luxuniversity_db.dbo.student s
    JOIN luxuniversity_db.dbo.student_level sl ON s.current_level_id = sl.level_id
    JOIN luxuniversity_db.dbo.semester sem ON sem.is_current = 1
    WHERE sl.level_number = 100
      AND s.enrollment_status = 'Active'
      AND NOT EXISTS (
          SELECT 1 FROM luxuniversity_db.dbo.course_registration cr
          JOIN luxuniversity_db.dbo.course c ON cr.course_id = c.course_id
          WHERE cr.student_id = s.student_id
            AND cr.semester_id = sem.semester_id
            AND c.course_code = 'SER001'
      );
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('100L students not registered for SER001','REGISTRATION','WARNING',@v_count,
                CONCAT(@v_count,' active 100L students have not registered SER001 this semester.'), @p_etl_run_id);
        SET @p_warnings += 1;
    END

    -- ── DQ-05: Students exceeding 24 credit unit limit ───
    SELECT @v_count = COUNT(*) FROM (
        SELECT cr.student_id, cr.semester_id, SUM(c.credit_units) AS total_cu
        FROM luxuniversity_db.dbo.course_registration cr
        JOIN luxuniversity_db.dbo.course c ON cr.course_id = c.course_id
        GROUP BY cr.student_id, cr.semester_id
        HAVING SUM(c.credit_units) > 24
    ) x;
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Students exceeding 24 credit unit limit','REGISTRATION','ERROR',@v_count,
                CONCAT(@v_count,' student-semester combinations exceed 24 credit unit maximum.'), @p_etl_run_id);
        SET @p_errors += 1;
    END

    -- ── DQ-06: Course results for dropped registrations ──
    SELECT @v_count = COUNT(*)
    FROM luxuniversity_db.dbo.course_result res
    JOIN luxuniversity_db.dbo.course_registration cr ON res.registration_id = cr.registration_id
    WHERE cr.registration_status = 'Dropped';
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Results exist for Dropped registrations','RESULTS','WARNING',@v_count,
                CONCAT(@v_count,' results found for registrations with status=Dropped.'), @p_etl_run_id);
        SET @p_warnings += 1;
    END

    -- ── DQ-07: Duplicate matric numbers (should be zero) ─
    SELECT @v_count = COUNT(*) FROM (
        SELECT student_matric_no FROM luxuniversity_db.dbo.student
        GROUP BY student_matric_no HAVING COUNT(*) > 1
    ) x;
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Duplicate matric numbers','STUDENT','ERROR',@v_count,
                CONCAT(@v_count,' matric numbers appear more than once.'), @p_etl_run_id);
        SET @p_errors += 1;
    END

    -- ── DQ-08: Semesters with zero registrations (warning) ─
    SELECT @v_count = COUNT(*)
    FROM luxuniversity_db.dbo.semester sem
    WHERE sem.end_date < CAST(GETDATE() AS DATE)
      AND NOT EXISTS (
          SELECT 1 FROM luxuniversity_db.dbo.course_registration cr
          WHERE cr.semester_id = sem.semester_id
      );
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Closed semesters with zero registrations','COURSE','WARNING',@v_count,
                CONCAT(@v_count,' past semesters have no course registrations at all.'), @p_etl_run_id);
        SET @p_warnings += 1;
    END

    -- ── DQ-09: Grade mismatch (grade doesn't match total_score range) ─
    SELECT @v_count = COUNT(*)
    FROM luxuniversity_db.dbo.course_result res
    JOIN luxuniversity_db.dbo.grade_scale gs ON res.grade = gs.grade
    WHERE res.total_score NOT BETWEEN gs.min_score AND gs.max_score;
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Grade does not match total score range','RESULTS','ERROR',@v_count,
                CONCAT(@v_count,' results have a grade that does not match the score-to-grade mapping.'), @p_etl_run_id);
        SET @p_errors += 1;
    END

    -- ── DQ-10: Orphaned registrations (no result after semester ended) ─
    SELECT @v_count = COUNT(*)
    FROM luxuniversity_db.dbo.course_registration cr
    JOIN luxuniversity_db.dbo.semester sem ON cr.semester_id = sem.semester_id
    WHERE sem.end_date < CAST(GETDATE() AS DATE)
      AND cr.registration_status = 'Registered'
      AND NOT EXISTS (
          SELECT 1 FROM luxuniversity_db.dbo.course_result res
          WHERE res.registration_id = cr.registration_id
      );
    IF @v_count > 0
    BEGIN
        INSERT INTO luxuniversity_db.dbo.dq_check_log
            (check_name, check_category, severity, records_flagged, detail, etl_run_id)
        VALUES ('Registrations with no result after semester ended','RESULTS','WARNING',@v_count,
                CONCAT(@v_count,' past-semester registrations have no result entered.'), @p_etl_run_id);
        SET @p_warnings += 1;
    END

END;
GO

-- ============================================================
-- USAGE EXAMPLES
-- ============================================================

-- Run incremental ETL (production):
-- EXEC etl.sp_run_incremental_etl;

-- Force full reload (first run or after major OLTP changes):
-- EXEC etl.sp_run_incremental_etl @p_force_full_reload = 1;

-- Check ETL run history:
-- SELECT etl_run_id, run_started_at, run_finished_at, status,
--        rows_inserted, rows_updated, scd2_rows_closed,
--        dq_errors, dq_warnings,
--        DATEDIFF(SECOND, run_started_at, run_finished_at) AS duration_sec
-- FROM etl_log ORDER BY etl_run_id DESC;

-- Check DQ failures:
-- SELECT * FROM luxuniversity_db.dbo.dq_check_log
-- ORDER BY checked_at DESC;

-- View current SCD2 student dimension:
-- SELECT * FROM luxuniversity_dw.dbo.dim_student WHERE is_current=1;

-- View full SCD2 history for one student:
-- SELECT * FROM luxuniversity_dw.dbo.dim_student
-- WHERE student_matric_no='CST/2022/001'
-- ORDER BY effective_date;

-- ============================================================
-- END OF 04_etl_incremental.sql
-- ============================================================

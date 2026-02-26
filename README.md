# LuxUniversity DB

> A production-grade university database system modelled on **Obafemi Awolowo University (OAU)** — built for Microsoft SQL Server with a proper two-tier architecture: OLTP source of truth + OLAP data warehouse.

![SQL Server](https://img.shields.io/badge/Microsoft%20SQL%20Server-2016%2B-blue?logo=microsoftsqlserver)
![Azure SQL](https://img.shields.io/badge/Azure%20SQL-Compatible-0078D4?logo=microsoftazure)
![Architecture](https://img.shields.io/badge/Architecture-OLTP%20%2B%20OLAP-purple)
![Security](https://img.shields.io/badge/Security-Row--Level%20Security-red)
![License](https://img.shields.io/badge/License-MIT-green)

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Quick Start](#2-quick-start)
3. [File Guide](#3-file-guide)
4. [OLTP Database — luxuniversity_db](#4-oltp-database--luxuniversity_db)
5. [Data Warehouse — luxuniversity_dw](#5-data-warehouse--luxuniversity_dw)
6. [ETL Pipeline](#6-etl-pipeline)
7. [Row-Level Security](#7-row-level-security)
8. [Data Quality Framework](#8-data-quality-framework)
9. [Reporting Layer](#9-reporting-layer-rpt-schema)
10. [Institutional Structure](#10-institutional-structure)
11. [Course System](#11-course-system)
12. [Business Rules](#12-business-rules--enforcement)
13. [Stored Procedures](#13-stored-procedures)
14. [Analytical Queries](#14-analytical-queries)
15. [Design Decisions](#15-design-decisions)

---

## 1. Architecture Overview

This project separates transactional and analytical workloads into two dedicated databases — the correct production architecture for any data platform.

```
┌─────────────────────────────────────────────────────────────────┐
│                      APPLICATION LAYER                          │
│              Student Portal  |  Staff Portal  |  Registry       │
└───────────────────────────┬─────────────────────────────────────┘
                            │  read/write
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                  luxuniversity_db  (OLTP)                        │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌────────────────────┐    │
│  │   Students   │  │  Courses &   │  │  Registration &    │    │
│  │   & Staff    │  │  Prerequisites│  │  Results           │    │
│  └──────────────┘  └──────────────┘  └────────────────────┘    │
│                                                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Row-Level Security  |  Temporal Tables  |  DQ Checks   │   │
│  └─────────────────────────────────────────────────────────┘   │
└───────────────────────────┬─────────────────────────────────────┘
                            │  Incremental ETL (daily/hourly)
                            │  04_etl_incremental.sql
                            │  → SCD Type 2 on dim_student
                            │  → High-water mark per entity
                            │  → DQ gate before every load
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                  luxuniversity_dw  (OLAP)                        │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  dim_student  │  dim_course  │  dim_academic_period  │   │  │
│  │  dim_staff    │  dim_date    │  dim_geography         │   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  fact_enrollment  │  fact_student_gpa  │  fact_reg_event │  │
│  │  (CLUSTERED COLUMNSTORE INDEX — 10-100x faster)          │  │
│  └──────────────────────────────────────────────────────────┘  │
│                            ▼                                    │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              rpt.* — KPI Views for Dashboards             │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                            │  read-only
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│              BI / Reporting Layer                                │
│         Power BI  |  Excel  |                                  │
└─────────────────────────────────────────────────────────────────┘
```

---


## 2. Quick Start

### Prerequisites

- Microsoft SQL Server 2016+ or Azure SQL Database
- SQL Server Management Studio (SSMS 18+) 
- A login with `dbcreator` or `sysadmin` rights
- Both databases must be on the **same SQL Server instance** (ETL uses cross-database queries)


---

## 3. File Guide


| File | What it Creates | Key Features |
|---|---|---|
| `01_create_oltp.sql` | `luxuniversity_db` | 20 OLTP tables, 4 views, 4 stored procedures, temporal student table, RLS function + policy, ETL watermark table, DQ log table, extended properties, 14 performance indexes |
| `02_create_dw.sql` | `luxuniversity_dw` | 6 dimension tables, 3 fact tables with clustered columnstore indexes, `rpt` schema with 7 KPI views, `etl_log` table, Nigerian state geography dimension |
| `03_insert_sample_data.sql` | Seed data | Grade scale, 7 levels, 11 degree types, 14 faculties, 50+ departments, 50+ programmes, 100+ courses with descriptions, prerequisites, 10 students, 24+ registrations, 5 results, staff |
| `04_etl_incremental.sql` | ETL engine | `etl` schema, master proc `etl.sp_run_incremental_etl`, 8 sub-procedures (dim_date, dim_course, dim_period, dim_staff, SCD2 dim_student, fact_enrollment, fact_gpa, fact_reg_events), 10 DQ checks |
| `05_row_level_security.sql` | RBAC | 4 database roles, sample logins, `security_user_map` population, RLS policy enabled |
| `06_reporting_layer.sql` | Extra `rpt.*` views | Department GPA ranking, lecturer performance, programme completion rates, semester capacity |

---

## 4. OLTP Database — luxuniversity_db

### Schema Map

```
REFERENCE TABLES              INSTITUTIONAL STRUCTURE
─────────────────             ───────────────────────
academic_session              college
semester                        └─ faculty
student_level                        └─ department
degree_type                               └─ programme
grade_scale
course_category               COURSE CATALOG
                              ─────────────
STUDENT                       course
─────────                       ├─ course_prerequisite
student  ◄── TEMPORAL TABLE     └─ programme_course
  └─ student_history
  └─ student_level_history    OPERATIONS
                              ──────────
STAFF                         course_registration
─────                           └─ course_result
staff                           └─ registration_audit
  └─ course_assignment
                              INFRASTRUCTURE
                              ──────────────
                              etl_watermark
                              dq_check_log
                              security_user_map
```

### Temporal Table — Full Audit History on `student`

The `student` table is **system-versioned**. SQL Server automatically tracks every INSERT, UPDATE, and DELETE in a shadow history table `student_history`.

```sql
-- See what a student's record looked like on a specific past date
SELECT * FROM student
FOR SYSTEM_TIME AS OF '2023-06-01'
WHERE student_matric_no = 'CST/2022/001';

-- See all changes ever made to a student's record
SELECT * FROM student
FOR SYSTEM_TIME ALL
WHERE student_matric_no = 'CST/2022/001'
ORDER BY valid_from;

-- See what all students looked like at the start of 2024/2025 session
SELECT * FROM student
FOR SYSTEM_TIME AS OF '2024-09-01';
```

### OLTP Views

| View | Purpose |
|---|---|
| `vw_student_registration_summary` | Per-student course count, credit units, registration window status |
| `vw_student_transcript` | Full academic transcript with scores and grades |
| `vw_ser001_compliance` | Active 100L students showing SER001 registration status |
| `vw_course_prereq_chain` | Every course with its prerequisites and minimum grade requirements |

---

## 5. Data Warehouse — luxuniversity_dw

### Star Schema

```
                        ┌─────────────────┐
                        │   dim_student   │
                        │  (SCD Type 2)   │
                        └────────┬────────┘
                                 │
┌──────────────┐        ┌────────▼────────────┐        ┌──────────────────────┐
│  dim_course  ├────────►   fact_enrollment   ◄────────┤  dim_academic_period │
└──────────────┘        │  (COLUMNSTORE IDX)  │        └──────────────────────┘
                        └────────┬────────────┘
┌──────────────┐                 │          ┌──────────────┐
│  dim_staff   ├─────────────────┤          │  dim_date    │
└──────────────┘                 │          └──────┬───────┘
                                 │                 │
┌──────────────┐        ┌────────▼────────────┐   │
│ dim_geography├────────►   fact_student_gpa  ◄───┘
└──────────────┘        │  (COLUMNSTORE IDX)  │
                        └─────────────────────┘

                        ┌─────────────────────┐
                        │ fact_registration   │
                        │      _event         │
                        │  (COLUMNSTORE IDX)  │
                        └─────────────────────┘
```

### SCD Type 2 on dim_student

When the ETL detects that a student has changed programme, level, or status:

1. Existing `dim_student` row is **closed**: `expiry_date = today`, `is_current = 0`
2. New row is **inserted**: `effective_date = today`, `expiry_date = '9999-12-31'`, `is_current = 1`

This lets analytical queries ask historical questions:

```sql
-- What faculty was this student in when they sat their 300L exams?
SELECT fe.*, ds.faculty_name, ds.level_name
FROM fact_enrollment fe
JOIN dim_student ds ON fe.student_sk = ds.student_sk
-- The surrogate key (student_sk) links to the SPECIFIC historical version
WHERE ds.student_matric_no = 'CST/2022/001';
```

### Columnstore Indexes

All three fact tables use `CLUSTERED COLUMNSTORE INDEX`. This replaces the default row-store clustering with column-based compression and batch-mode execution:

```sql
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_enrollment ON fact_enrollment;
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_student_gpa ON fact_student_gpa;
CREATE CLUSTERED COLUMNSTORE INDEX cci_fact_reg_event ON fact_registration_event;
```

**Why this matters:** A query like `AVG(grade_point) GROUP BY faculty_name` on a million-row fact table runs in seconds with columnstore vs. minutes with row-store.

### dim_geography — Nigerian State Dimension

All 37 Nigerian states (including FCT) are pre-loaded with geopolitical zone and region for demographic analysis:

```sql
-- Student distribution by geopolitical zone
SELECT dg.geopolitical_zone, COUNT(DISTINCT ds.student_sk) AS students
FROM dim_student ds
JOIN dim_geography dg ON ds.state_of_origin = dg.state_name
WHERE ds.is_current = 1
GROUP BY dg.geopolitical_zone;
```

---

## 6. ETL Pipeline

### How It Works

```
etl.sp_run_incremental_etl
    │
    ├── Step 0: Run DQ checks (sp_run_dq_checks)
    │           └── If DQ ERRORs > 0 → ABORT and log FAILED
    │
    ├── Step 1: Read watermarks from luxuniversity_db.etl_watermark
    │           └── One timestamp per entity (student, course, result, etc.)
    │
    ├── Step 2: Load dim_date (idempotent, 2021-2030)
    │
    ├── Step 3: Load dimension tables
    │           ├── sp_load_dim_academic_period
    │           ├── sp_load_dim_course
    │           ├── sp_load_dim_staff
    │           └── sp_load_dim_student_scd2  ← SCD Type 2 logic here
    │
    ├── Step 4: Load fact tables
    │           ├── sp_load_fact_enrollment
    │           ├── sp_load_fact_student_gpa
    │           └── sp_load_fact_reg_events
    │
    ├── Step 5: Update watermarks in OLTP
    │           └── SET last_extracted_at = GETDATE() per entity
    │
    └── Step 6: Log run to etl_log (SUCCESS / FAILED / PARTIAL)
```

### Scheduling with SQL Server Agent

```sql
-- Create a daily job at 1:00 AM
USE msdb;
EXEC sp_add_job @job_name = 'LuxUniversity DW Incremental ETL';
EXEC sp_add_jobstep
    @job_name = 'LuxUniversity DW Incremental ETL',
    @step_name = 'Run ETL',
    @command = 'EXEC luxuniversity_dw.etl.sp_run_incremental_etl;',
    @database_name = 'luxuniversity_dw';
EXEC sp_add_schedule @schedule_name = 'Daily 1AM',
    @freq_type = 4, @freq_interval = 1,
    @active_start_time = 010000;
EXEC sp_attach_schedule @job_name = 'LuxUniversity DW Incremental ETL',
    @schedule_name = 'Daily 1AM';
EXEC sp_add_jobserver @job_name = 'LuxUniversity DW Incremental ETL';
```

### Force Full Reload

```sql
-- Use when OLTP data has been bulk-modified or after major schema changes
EXEC luxuniversity_dw.etl.sp_run_incremental_etl @p_force_full_reload = 1;
```

### Monitor ETL Health

```sql
-- Run history
SELECT etl_run_id, run_started_at, status,
       rows_inserted, rows_updated, scd2_rows_closed,
       dq_errors, dq_warnings,
       DATEDIFF(SECOND, run_started_at, run_finished_at) AS duration_sec
FROM luxuniversity_dw.dbo.etl_log
ORDER BY etl_run_id DESC;

-- DQ failures
SELECT check_name, severity, records_flagged, detail, checked_at
FROM luxuniversity_db.dbo.dq_check_log
ORDER BY checked_at DESC;
```

---

## 7. Row-Level Security

Four roles with different data visibility, enforced at the SQL Server engine layer:

| Role | What They See |
|---|---|
| `student_role` | Only their own `student` row, their own `course_registration` and `course_result` rows |
| `lecturer_role` | All students registered in courses they are assigned to teach |
| `faculty_admin_role` | All students in their faculty |
| `registry_admin_role` | Everything — bypasses the RLS predicate entirely |
| `dw_etl_user` | Read-only SELECT on OLTP tables (for ETL pipeline) |

### How It Works

The RLS inline function `fn_rls_student_predicate` is added as a FILTER PREDICATE and BLOCK PREDICATE on the `student` table. Every query that touches `student` automatically gets the predicate injected — no application code required.

```sql
-- A student user running this query only sees their own row
SELECT * FROM student;

-- A faculty admin only sees students in their faculty
SELECT * FROM student;

-- A registry admin sees everyone
SELECT * FROM student;
```

### Assigning a User to a Role

```sql
-- Map a new student login
INSERT INTO security_user_map (db_username, role_name, entity_id)
VALUES ('matric_cst2024001', 'student', 
        (SELECT student_id FROM student WHERE student_matric_no = 'CST/2024/001'));

-- Add them to the database role
ALTER ROLE student_role ADD MEMBER matric_cst2024001;
```

---

## 8. Data Quality Framework

10 DQ checks run before every ETL load. Results are logged to `luxuniversity_db.dbo.dq_check_log`.

| Check ID | Name | Severity | Blocks ETL? |
|---|---|---|---|
| DQ-01 | Students with NULL programme_id | ERROR | Yes |
| DQ-02 | Results with total_score > 100 | ERROR | Yes |
| DQ-03 | Registrations after semester end date | WARNING | No |
| DQ-04 | 100L students not registered for SER001 | WARNING | No |
| DQ-05 | Students exceeding 24 credit unit limit | ERROR | Yes |
| DQ-06 | Results for Dropped registrations | WARNING | No |
| DQ-07 | Duplicate matric numbers | ERROR | Yes |
| DQ-08 | Closed semesters with zero registrations | WARNING | No |
| DQ-09 | Grade does not match total score range | ERROR | Yes |
| DQ-10 | Registrations with no result after semester ended | WARNING | No |

ERROR-severity failures abort the ETL and log `status = 'FAILED'` in `etl_log`. WARNING-severity issues are logged but ETL continues.

---

## 9. Reporting Layer (rpt Schema)

All reporting views live in `luxuniversity_dw.rpt.*`. BI tools connect here — never directly to the OLTP.

| View | Key Metrics |
|---|---|
| `rpt.vw_faculty_performance` | Pass rate, failure rate, distinction rate, avg GPA per faculty per semester |
| `rpt.vw_at_risk_students` | Students with CGPA < 1.5 or 3+ failures, with risk level classification |
| `rpt.vw_ser001_compliance_rate` | % of 100L students who registered SER001, by faculty per session |
| `rpt.vw_course_failure_rate` | Failure rate per course — flags HIGH RISK (>40%) and ELEVATED (>25%) courses |
| `rpt.vw_registration_behaviour` | Late registration rates, avg days before deadline, by faculty and level |
| `rpt.vw_credit_load_distribution` | Min/max/avg credit units per student, by faculty and level |
| `rpt.vw_student_diversity` | Student count and avg CGPA by geopolitical zone and faculty |
| `rpt.vw_department_gpa_ranking` | Department league table ranked by CGPA (from `06_reporting_layer.sql`) |

### Sample: Find at-risk students right now

```sql
USE luxuniversity_dw;
SELECT * FROM rpt.vw_at_risk_students
ORDER BY cgpa ASC;
```

### Sample: Which courses need curriculum review?

```sql
SELECT course_code, course_title, faculty_name, failure_rate_pct, risk_flag
FROM rpt.vw_course_failure_rate
WHERE risk_flag IN ('HIGH RISK', 'ELEVATED')
ORDER BY failure_rate_pct DESC;
```

---

## 10. Institutional Structure 

The database models the complete Nigerian tertiary institution hierarchy:

```
College of Health Sciences (CHS)
  └── Faculty of Basic Medical Sciences (BMS)
  └── Faculty of Clinical Sciences (CLINSCI)
  └── Faculty of Dentistry (DENT)
  └── Faculty of Pharmacy (PHARM)

Direct Reporting Faculties:
  Faculty of Administration        (ADMIN)
  Faculty of Agriculture           (AGRIC)
  Faculty of Arts                  (ARTS)
  Faculty of Education             (EDU)
  Faculty of Environmental Design  (EDM)
  Faculty of Law                   (LAW)
  Faculty of Science               (SCI)
  Faculty of Social Sciences       (SOC)
  Faculty of Technology            (TECH)
  Faculty of Computing Science     (CST)
```

### Matric Number Format

Pattern: `FACULTY_CODE/ADMISSION_YEAR/SEQUENCE`

| Example | Meaning |
|---|---|
| `CST/2024/001` | First CST student admitted in 2024/2025 |
| `LAW/2020/001` | First Law student admitted in 2020/2021 |
| `SCI/2024/001` | First Science student admitted in 2024/2025 |

### Programme Durations

| Degree | Duration |
|---|---|
| B.Sc, B.A, LL.B, B.Ed, B.Com | 4 years |
| B.Eng, B.Agric, B.Pharm, B.Arch | 5 years |
| MBBS, B.DS | 6 years |

---

## 11. Course System

### Three-Tier Classification

| Type | Description | Example |
|---|---|---|
| `MAJOR` | Core departmental course — compulsory within programme | `CSC301 Operating Systems` |
| `ELECTIVE` | Optional — student chooses from approved list | `CSC405 Cloud Computing` |
| `COMPULSORY_SE` | University-wide — every student at a given level must register | `SER001 Use of English` |

### SER001 — Compulsory Special Elective

- Owned by the **English Department, Faculty of Arts**
- `is_compulsory_se = 1` on the `course` table
- Mapped to every programme as `COMPULSORY_SE` in `programme_course`
- Targeted at 100L, First Semester
- Non-compliance surfaced by `vw_ser001_compliance` in OLTP and `rpt.vw_ser001_compliance_rate` in DW

### Prerequisite Modelling

Self-referencing many-to-many on `course`. Each prerequisite has a configurable `min_grade`:

```
CSC102 ──► CSC201 ──► CSC301
                 ──► CSC302 ──► CSC401 (also requires CSC303, min grade E)
AIT201 ──► AIT202 ──► AIT301 ──► AIT302
ECO201 ──► ECO301 (min grade C — stricter) ──► ECO401
BCH201 ──► BCH202 ──► BCH301
```

`sp_register_course` automatically validates all prerequisites before inserting a registration. Failures are logged to `registration_audit`.

---

## 12. Business Rules & Enforcement

All rules are enforced at the **database engine layer**, not application code. Application bugs cannot bypass them.

| Rule | Where Enforced |
|---|---|
| Registration deadline cannot be exceeded | `sp_register_course` — checks `CAST(GETDATE() AS DATE) > reg_deadline`; rejects and logs to `registration_audit` |
| All prerequisites must be passed | `sp_register_course` — queries `course_prerequisite` + `course_result`; checks grade >= `min_grade` |
| Max 24 credit units per semester | `sp_register_course` — sums current credit load before registering |
| SER001 is compulsory for all 100L students | Schema (`is_compulsory_se=1`, `programme_course` mapping) + DQ check DQ-04 |
| A course cannot be its own prerequisite | `CHECK` constraint: `course_id <> required_course_id` |
| Registration deadline within semester dates | `CHECK` constraint: `reg_deadline <= end_date` |
| No duplicate registrations | `UNIQUE` constraint on `(student_id, course_id, semester_id)` |
| Course type must be valid | `CHECK` on `course_registration.course_type_taken` |
| Enrollment status restricted to valid values | `CHECK` on `student.enrollment_status` |
| Semester names restricted to First/Second | `CHECK` on `semester.semester_name` |

---

## 13. Stored Procedures

### OLTP Procedures

| Procedure | Parameters | Description |
|---|---|---|
| `sp_register_course` | `@student_id`, `@course_id`, `@semester_id`, `@course_type`, `@result OUTPUT` | Validates deadline, credit load, duplicates, and prerequisites before inserting |
| `sp_promote_student` | `@student_id`, `@session_id`, `@result OUTPUT` | Calculates GPA, updates level, merges into `student_level_history` |
| `sp_get_student_courses` | `@matric_no`, `@semester_id` | All courses for a student in a given semester |
| `sp_get_transcript` | `@matric_no` | Full academic transcript |

### ETL Procedures (luxuniversity_dw.etl.*)

| Procedure | Purpose |
|---|---|
| `etl.sp_run_incremental_etl` | Master entry point — orchestrates all steps |
| `etl.sp_run_dq_checks` | Runs all 10 DQ checks, logs results, returns error/warning counts |
| `etl.sp_load_dim_date` | Idempotent date dimension load (2021–2030) |
| `etl.sp_load_dim_academic_period` | Loads semesters + sessions |
| `etl.sp_load_dim_course` | Loads course dimension with faculty/dept context |
| `etl.sp_load_dim_staff` | Loads staff dimension |
| `etl.sp_load_dim_student_scd2` | SCD Type 2 — detects changes, closes old rows, inserts new |
| `etl.sp_load_fact_enrollment` | Loads enrollment fact with boolean flags |
| `etl.sp_load_fact_student_gpa` | Loads aggregate GPA fact |
| `etl.sp_load_fact_reg_events` | Loads registration events including rejected attempts |

### Usage Examples

```sql
-- Register a course
DECLARE @result NVARCHAR(500);
EXEC sp_register_course
    @p_student_id  = 1,
    @p_course_id   = 5,
    @p_semester_id = 7,
    @p_course_type = N'MAJOR',
    @p_result      = @result OUTPUT;
SELECT @result;
-- 'SUCCESS: Course registered successfully.'
-- 'ERROR: Registration deadline has passed.'
-- 'ERROR: 2 prerequisite(s) not satisfied.'
-- 'ERROR: Registration would exceed 24 credit unit maximum.'

-- Get transcript
EXEC sp_get_transcript N'CST/2022/001';

-- Promote student after session
DECLARE @result NVARCHAR(500);
EXEC sp_promote_student 1, 4, @result OUTPUT;
SELECT @result;  -- 'SUCCESS: Promoted to 200L. GPA: 3.50'

-- Run ETL
EXEC luxuniversity_dw.etl.sp_run_incremental_etl;
```

---

## 14. Analytical Queries

### OLTP Queries

```sql
-- Current semester registration overview
SELECT * FROM vw_student_registration_summary ORDER BY faculty_name;

-- SER001 compliance check
SELECT * FROM vw_ser001_compliance WHERE ser001_status = 'NOT Registered';

-- Full prerequisite chain
SELECT * FROM vw_course_prereq_chain ORDER BY course_level, course_code;
```

### DW / Analytical Queries

```sql
-- Faculty performance comparison
SELECT * FROM rpt.vw_faculty_performance ORDER BY avg_grade_point DESC;

-- Courses with high failure rates (curriculum red flags)
SELECT course_code, course_title, failure_rate_pct, risk_flag
FROM rpt.vw_course_failure_rate
WHERE risk_flag != 'NORMAL'
ORDER BY failure_rate_pct DESC;

-- At-risk students for academic support intervention
SELECT student_matric_no, full_name, faculty_name, cgpa, courses_failed, risk_level
FROM rpt.vw_at_risk_students
ORDER BY cgpa ASC;

-- Registration behaviour — which faculty registers latest?
SELECT faculty_name, avg_days_before_deadline, late_rate_pct
FROM rpt.vw_registration_behaviour
ORDER BY avg_days_before_deadline ASC;

-- Student diversity by geopolitical zone
SELECT geopolitical_zone, region, student_count, avg_cgpa
FROM rpt.vw_student_diversity
ORDER BY student_count DESC;

-- Year-over-year GPA trends by faculty
SELECT ds.faculty_name, dp.session_name,
       ROUND(AVG(CAST(fg.session_gpa AS FLOAT)), 2) AS avg_gpa
FROM luxuniversity_dw.dbo.fact_student_gpa fg
JOIN luxuniversity_dw.dbo.dim_student ds ON fg.student_sk = ds.student_sk AND ds.is_current = 1
JOIN luxuniversity_dw.dbo.dim_academic_period dp ON fg.period_sk = dp.period_sk
GROUP BY ds.faculty_name, dp.session_name
ORDER BY ds.faculty_name, dp.session_name;
```

---

## 15. Design Decisions

### Why separate OLTP and DW databases?

OLTP and OLAP have conflicting needs. OLTP needs low-latency row-level reads and writes with minimal locking. OLAP needs full-table column scans with batch aggregation. Sharing a database means analytical queries block transactions and row-store indexes hurt scan performance. Industry standard is complete separation.

### Why SCD Type 2 on dim_student only?

`dim_student` carries attributes that genuinely change over time (level, programme, status) and where historical accuracy matters — if a student was in Faculty of Science when they passed a course in 2022, that fact must be preserved even after they transfer. `dim_course` uses Type 1 (overwrite) because course metadata changes are corrections, not meaningful historical events.

### Why NVARCHAR instead of VARCHAR?

Nigerian names frequently include diacritics and characters outside ASCII. NVARCHAR uses UTF-16 encoding and handles all of them. The storage overhead is negligible for this dataset size.

### Why PERSISTED computed columns?

`total_score AS (ISNULL(ca_score,0) + ISNULL(exam_score,0)) PERSISTED` stores the result on disk rather than computing it at query time. This means the value is indexable and available to the ETL without re-calculation.

### Why `RETURN` instead of `RAISERROR` in stored procedures?

`RAISERROR` with high severity rolls back calling transactions and produces error output that some client tools handle poorly. Using `RETURN` with an OUTPUT parameter for the result message keeps the procedure behaviour clean and predictable — the caller decides what to do with a rejection message.

### Why `SET XACT_ABORT ON` in the ETL master procedure?

`SET XACT_ABORT ON` means any run-time error automatically rolls back the entire transaction. Without it, a partial failure in the middle of an ETL run could leave the DW in an inconsistent state, with some dimensions loaded but not others. Pairing this with `BEGIN TRY / BEGIN CATCH` gives precise error capture with clean rollback.

### Why enforce business rules at the database layer?

Application code can be bypassed — direct database connections, SSMS queries, bulk imports. Constraints, CHECK constraints, stored procedure logic, and RLS predicates cannot be bypassed regardless of how a user connects. Every critical rule in this system is enforced at the engine level.

---


### Verify Everything Works

```sql
-- OLTP checks
USE luxuniversity_db;
SELECT COUNT(*) AS faculties    FROM faculty;           -- 14
SELECT COUNT(*) AS departments  FROM department;        -- 50+
SELECT COUNT(*) AS courses      FROM course;            -- 100+
SELECT COUNT(*) AS students     FROM student;           -- 10
SELECT COUNT(*) AS registrations FROM course_registration; -- 24+

-- DW checks
USE luxuniversity_dw;
SELECT COUNT(*) AS dim_students  FROM dim_student;      -- 10+
SELECT COUNT(*) AS dim_courses   FROM dim_course;       -- 100+
SELECT COUNT(*) AS fact_rows     FROM fact_enrollment;  -- 24+
SELECT status, COUNT(*) FROM etl_log GROUP BY status;   -- should show SUCCESS

-- ETL log
SELECT etl_run_id, status, rows_inserted, dq_errors, dq_warnings,
       DATEDIFF(SECOND, run_started_at, run_finished_at) AS duration_sec
FROM etl_log ORDER BY etl_run_id DESC;

-- Temporal table — time-travel query
SELECT * FROM luxuniversity_db.dbo.student
FOR SYSTEM_TIME AS OF '2024-01-01';
```

---


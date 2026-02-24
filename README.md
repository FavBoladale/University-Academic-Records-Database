# 🎓 LuxUniversity DB

> A comprehensive, production-grade university database system modelled on the **Obafemi Awolowo University (OAU)** faculty structure — built for Microsoft SQL Server.

![SQL Server](https://img.shields.io/badge/Microsoft%20SQL%20Server-2016%2B-blue?logo=microsoftsqlserver)
![Azure SQL](https://img.shields.io/badge/Azure%20SQL-Supported-0078D4?logo=microsoftazure)
![License](https://img.shields.io/badge/License-MIT-green)
![Status](https://img.shields.io/badge/Status-Production%20Ready-brightgreen)

---

## 📋 Table of Contents

1. [Project Overview](#1-project-overview)
2. [Quick Start](#2-quick-start)
3. [Institutional Structure](#3-institutional-structure-oau)
4. [Schema Design](#4-schema-design)
5. [Course System](#5-course-system)
6. [Business Rules](#6-business-rules--enforcement)
7. [Stored Procedures](#7-stored-procedures)
8. [Views](#8-views)
9. [Analytical Queries](#9-analytical-queries-dimensional-model)
10. [File Guide](#10-file-guide)
11. [Matric Number Format](#11-matric-number-format)
12. [Extending the Database](#12-extending-the-database)
13. [Developer Notes](#13-developer-notes)

---

## 1. Project Overview

**LuxUniversity DB** is a fully structured relational database for managing university academic operations. It covers student enrolment, course registration, grading, staff management, prerequisite enforcement, and analytics — all backed by real database-layer constraints and stored procedures.

The system is built on **two distinct layers**:

| Layer | Purpose |
|---|---|
| **OLTP (Transactional)** | Day-to-day operations — registration, results, promotions, staff assignments |
| **Dimensional (Star Schema)** | Analytics and BI — GPA trends, faculty performance, compliance reporting |

### At a Glance

| Property | Detail |
|---|---|
| Database Name | `luxuniversity_db` |
| RDBMS | Microsoft SQL Server 2016+ / Azure SQL Database |
| Collation | `Latin1_General_CI_AS` |
| Faculties Modelled | 14 (all OAU faculties, including CHS sub-faculties) |
| Total Tables | 26 OLTP + 6 Dimensional = **32 tables** |
| Views | 4 |
| Stored Procedures | 4 |
| Indexes | 11 performance indexes |

---

## 2. Quick Start

### Prerequisites

- Microsoft SQL Server 2016+ **or** Azure SQL Database
- SQL Server Management Studio (SSMS 18+) or Azure Data Studio
- A login with `dbcreator` or `sysadmin` rights

### Installation

```sql
-- Step 1: Run DDL (creates DB, all tables, views, procedures, indexes)
-- Open and execute: 01_create_tables.sql

-- Step 2: Load sample data
-- Open and execute: 02_insert_sample_data.sql
```

### Verify Installation

```sql
USE luxuniversity_db;

SELECT COUNT(*) AS faculty_count    FROM faculty;       -- Expected: 14
SELECT COUNT(*) AS dept_count       FROM department;    -- Expected: 50+
SELECT COUNT(*) AS course_count     FROM course;        -- Expected: 100+
SELECT COUNT(*) AS student_count    FROM student;       -- Expected: 10
SELECT COUNT(*) AS dim_course_count FROM dim_course;    -- Matches course table
```

---

## 3. Institutional Structure (OAU)

The database models the complete OAU organisational hierarchy:

```
College (optional)
  └── Faculty
        └── Department
              └── Programme (Degree)
```

Four faculties sit under the **College of Health Sciences**. All others report directly.

| # | Faculty | Code | College |
|---|---------|------|---------|
| 1 | Faculty of Administration | ADMIN | — |
| 2 | Faculty of Agriculture | AGRIC | — |
| 3 | Faculty of Arts | ARTS | — |
| 4 | Faculty of Basic Medical Sciences | BMS | College of Health Sciences |
| 5 | Faculty of Clinical Sciences | CLINSCI | College of Health Sciences |
| 6 | Faculty of Dentistry | DENT | College of Health Sciences |
| 7 | Faculty of Education | EDU | — |
| 8 | Faculty of Environmental Design and Management | EDM | — |
| 9 | Faculty of Law | LAW | — |
| 10 | Faculty of Pharmacy | PHARM | College of Health Sciences |
| 11 | Faculty of Science | SCI | — |
| 12 | Faculty of Social Sciences | SOC | — |
| 13 | Faculty of Technology | TECH | — |
| 14 | Faculty of Computing Science and Technology | CST | — |

### Programme Durations

| Programme Type | Duration |
|---|---|
| Standard B.Sc / B.A / LL.B / B.Ed | 4 years |
| B.Eng / B.Agric / B.Pharm / Architecture | 5 years |
| MBBS (Medicine and Surgery) | 6 years |

---

## 4. Schema Design

### 4.1 OLTP Tables

| Table | Group | Purpose |
|---|---|---|
| `academic_session` | Reference | Academic years e.g. `2024/2025` with start/end dates and active flag |
| `semester` | Reference | First and Second semesters with registration deadlines |
| `student_level` | Reference | 100L through 700L with numeric values for promotion logic |
| `degree_type` | Reference | B.Sc, B.A, MBBS, LL.B, B.Pharm, B.Eng, B.Agric, B.DS, B.Ed |
| `college` | Structure | College of Health Sciences grouping |
| `faculty` | Structure | All 14 OAU faculties |
| `department` | Structure | All departments with Head of Department field |
| `programme` | Structure | Degree programmes per department with duration in years |
| `course_category` | Reference | MAJOR, ELECTIVE, COMPULSORY_SE, GEN_STUDIES, COMMON |
| `course` | Catalog | Full course catalog with code, title, description, credit units, level |
| `course_prerequisite` | Catalog | Self-referencing prerequisite map with minimum grade thresholds |
| `programme_course` | Mapping | Courses assigned to programmes with type classification |
| `student` | Core | Enrolled students with programme, current level, and status |
| `student_level_history` | Core | GPA, CGPA, and credits earned per student per session |
| `course_registration` | Core | Student course registrations per semester |
| `registration_audit` | Audit | Log of all registration attempts including late/rejected |
| `grade_scale` | Reference | A=5.0 GP down to F=0.0 GP with score ranges |
| `course_result` | Core | CA score, exam score, computed total, grade, and grade point |
| `staff` | HR | Academic staff with department and designation |
| `course_assignment` | Schedule | Lecturer assignments to courses per semester |

### 4.2 Dimensional Tables (Star Schema)

```
                  ┌─────────────┐
                  │ dim_student │
                  └──────┬──────┘
                         │
┌─────────────┐   ┌──────▼──────────┐   ┌──────────────────────┐
│  dim_course ├───► fact_enrollment  ◄───┤ dim_academic_period  │
└─────────────┘   └──────┬──────────┘   └──────────────────────┘
                         │
                  ┌──────▼──────┐
                  │  dim_date   │
                  └─────────────┘
```

| Table | Type | Purpose |
|---|---|---|
| `dim_date` | Dimension | Date dimension 2021–2025: day, month, quarter, weekend flag |
| `dim_student` | Dimension | Type 2 SCD snapshot — supports historical GPA analysis |
| `dim_course` | Dimension | Flattened course attributes including faculty and department |
| `dim_academic_period` | Dimension | Session and semester combination with registration deadline |
| `fact_enrollment` | Fact | One row per student-course-semester with scores, grade, pass/fail |
| `fact_student_gpa` | Fact | Aggregated GPA per student per session |
| `fact_registration_event` | Fact | Registration timing relative to deadline for compliance analytics |

---

## 5. Course System

### 5.1 Three-Tier Course Classification

Every course assigned to a programme carries exactly one type:

| Type | Description | Example |
|---|---|---|
| `MAJOR` | Core departmental courses — compulsory within the programme | `CSC301 Operating Systems` for CS students |
| `ELECTIVE` | Optional — student selects from an approved list | `CSC405 Cloud Computing` |
| `COMPULSORY_SE` | University-wide compulsory special elective for all students | `SER001 Use of English` for every 100L student |

### 5.2 SER001 — Compulsory Special Elective

`SER001 (Use of English)` is the only `COMPULSORY_SE` course in the base dataset, though the schema supports as many as needed.

- Owned by the **English Department, Faculty of Arts**
- Mapped to **every programme** via `programme_course` with `course_type = 'COMPULSORY_SE'`
- Flagged `is_compulsory_se = 1` on the `course` table
- Targeted at **100L, First Semester**
- Compliance is monitored via `vw_ser001_compliance`

```sql
-- Check which 100L students have NOT registered SER001
SELECT * FROM vw_ser001_compliance
WHERE ser001_status = 'NOT Registered';
```

### 5.3 Prerequisite Modelling

The `course_prerequisite` table is a **self-referencing many-to-many** on the `course` table.

**How it works:**

```
course_prerequisite
┌──────────────┬────────────────────┬────────────┐
│  course_id   │ required_course_id │  min_grade │
├──────────────┼────────────────────┼────────────┤
│ CSC401 (AI)  │ CSC302 (DBMS)      │     E      │
│ CSC401 (AI)  │ CSC303 (Networks)  │     E      │
│ ECO301       │ ECO201             │     C      │  ← stricter
│ AIT301       │ AIT202             │     D      │
└──────────────┴────────────────────┴────────────┘
```

Key rules:
- A course can declare **multiple prerequisites** — one row per requirement
- `min_grade` is configurable per relationship — some require grade C, others only E
- A `CHECK` constraint prevents self-referencing: `course_id <> required_course_id`
- `sp_register_course` **automatically validates all prerequisites** before registration

**Prerequisite chains in the sample data:**

```
CSC102 ──► CSC201 ──► CSC301
                 ──► CSC302 ──► CSC401 (also requires CSC303)
AIT201 ──► AIT202 ──► AIT301 ──► AIT302
ECO201 ──► ECO301 (min C) ──► ECO401
BCH201 ──► BCH202 ──► BCH301
```

---

## 6. Business Rules & Enforcement

All rules are enforced **at the database layer**, not just in application code.

| Rule | Enforcement | Detail |
|---|---|---|
| Registration deadline must not be exceeded | SP + Audit | `sp_register_course` checks `CAST(GETDATE() AS DATE) > reg_deadline`; late attempts logged to `registration_audit` |
| All prerequisites must be passed before registration | SP | Procedure queries `course_prerequisite` and `course_result` to verify grade >= `min_grade` per prerequisite |
| SER001 is compulsory for all 100-level students | Schema + View | `is_compulsory_se=1`; mapped to every programme as `COMPULSORY_SE`; `vw_ser001_compliance` surfaces non-compliance |
| A course cannot be its own prerequisite | CHECK | `chk_no_self_prereq`: `course_id <> required_course_id` |
| Registration deadline must fall within semester dates | CHECK | `chk_reg_deadline`: `reg_deadline <= end_date` |
| No duplicate registrations per student per semester | UNIQUE | `uq_student_course_sem`: UNIQUE(`student_id`, `course_id`, `semester_id`) |
| Course type must be MAJOR, ELECTIVE, or COMPULSORY_SE | CHECK | `chk_reg_type` on `course_registration`; `chk_pc_type` on `programme_course` |
| Enrollment status restricted to valid values | CHECK | Active, Suspended, Withdrawn, Graduated, Deferred |

---

## 7. Stored Procedures

| Procedure | Parameters | Description |
|---|---|---|
| `sp_register_course` | `@student_id`, `@course_id`, `@semester_id`, `@course_type`, `@result OUTPUT` | Validates deadline, duplicate check, and all prerequisites before inserting the registration |
| `sp_promote_student` | `@student_id`, `@session_id`, `@result OUTPUT` | Calculates session GPA and promotes the student to the next level |
| `sp_get_student_courses` | `@matric_no`, `@semester_id` | Returns all courses registered by a student in a given semester |
| `sp_get_transcript` | `@matric_no` | Returns the full academic transcript ordered by session and semester |

### Usage Examples

**Register a course:**

```sql
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
```

**Get a student transcript:**

```sql
EXEC sp_get_transcript N'CST/2022/001';
```

**Get courses for a semester:**

```sql
EXEC sp_get_student_courses N'CST/2024/001', 7;
```

**Promote a student after results:**

```sql
DECLARE @result NVARCHAR(500);
EXEC sp_promote_student 1, 4, @result OUTPUT;
SELECT @result;
-- 'SUCCESS: Promoted to 200L.'
```

---

## 8. Views

| View | Description |
|---|---|
| `vw_student_registration_summary` | Per-student registration count, total credit units, and deadline open/closed status for the current semester |
| `vw_student_transcript` | Full academic transcript joining student, courses, results, and session context |
| `vw_ser001_compliance` | All active 100L students with their SER001 registration status |
| `vw_course_prereq_chain` | Every course alongside its prerequisites with level context — useful for curriculum planning |

### Sample Queries

```sql
-- Current semester registration overview
SELECT * FROM vw_student_registration_summary
ORDER BY faculty_name, student_name;

-- One student's full transcript
SELECT * FROM vw_student_transcript
WHERE student_matric_no = 'CST/2022/001'
ORDER BY session_name, semester_name;

-- Full prerequisite chain
SELECT * FROM vw_course_prereq_chain
ORDER BY course_level, course_code;
```

---

## 9. Analytical Queries (Dimensional Model)

**Average grade point per faculty:**

```sql
SELECT
    ds.faculty_name,
    ROUND(AVG(CAST(fe.grade_point AS FLOAT)), 2) AS avg_grade_point,
    COUNT(DISTINCT fe.student_sk)                AS student_count
FROM   fact_enrollment fe
JOIN   dim_student ds ON fe.student_sk = ds.student_sk
GROUP  BY ds.faculty_name
ORDER  BY avg_grade_point DESC;
```

**Top performing courses:**

```sql
SELECT
    dc.course_code,
    dc.course_title,
    ROUND(AVG(CAST(fe.total_score AS FLOAT)), 1) AS avg_score,
    COUNT(*)                                      AS enrollments
FROM   fact_enrollment fe
JOIN   dim_course dc ON fe.course_sk = dc.course_sk
GROUP  BY dc.course_sk, dc.course_code, dc.course_title
ORDER  BY avg_score DESC;
```

**Registration deadline compliance by faculty:**

```sql
SELECT
    ds.faculty_name,
    SUM(CASE WHEN re.was_late = 1 THEN 1 ELSE 0 END) AS late_registrations,
    COUNT(*)                                          AS total_registrations,
    ROUND(
        100.0 * SUM(CASE WHEN re.was_late = 1 THEN 1 ELSE 0 END) / COUNT(*), 1
    ) AS late_pct
FROM   fact_registration_event re
JOIN   dim_student ds ON re.student_sk = ds.student_sk
GROUP  BY ds.faculty_name
ORDER  BY late_pct DESC;
```

**Pass rate by academic level:**

```sql
SELECT
    dc.level_name,
    COUNT(*)                                                    AS total_results,
    SUM(CAST(fe.is_pass AS INT))                                AS passed,
    ROUND(100.0 * SUM(CAST(fe.is_pass AS INT)) / COUNT(*), 1)  AS pass_rate_pct
FROM   fact_enrollment fe
JOIN   dim_course dc ON fe.course_sk = dc.course_sk
GROUP  BY dc.level_name
ORDER  BY dc.level_name;
```

---

## 10. File Guide

```
luxuniversity_db/
├── 01_create_tables.sql        # DDL: database, tables, views, procedures, indexes
├── 02_insert_sample_data.sql   # DML: reference data, faculties, courses, students
└── README.md                   # This file
```

| File | Contents |
|---|---|
| `01_create_tables.sql` | Creates `luxuniversity_db`, all 32 tables, 4 views, 4 stored procedures, and 11 performance indexes. **Safe to re-run** — drops and recreates the database. |
| `02_insert_sample_data.sql` | Inserts grade scale, 7 student levels, 11 degree types, 14 faculties, 50+ departments, 50+ programmes, 100+ courses with full descriptions, 10 sample students across 6 faculties, course registrations, results, staff, and the full dimensional model. |

---

## 11. Matric Number Format

Pattern: `FACULTY_CODE/ADMISSION_YEAR/SEQUENCE`

| Example | Faculty | Meaning |
|---|---|---|
| `CST/2024/001` | Computing Science and Technology | First CST student admitted 2024/2025 |
| `SOC/2024/001` | Social Sciences | First Social Sciences student admitted 2024 |
| `LAW/2020/001` | Law | First Law student admitted 2020/2021 |
| `TECH/2023/001` | Technology | First Technology student admitted 2023/2024 |
| `SCI/2024/001` | Science | First Science student admitted 2024/2025 |

---

## 12. Extending the Database

| Extension | Tables to Add |
|---|---|
| **Exam Timetabling** | `exam_timetable (course_id, semester_id, exam_date, venue, invigilator_id)` |
| **Hostel Management** | `hostel`, `hostel_room`, `hostel_allocation (student_id, room_id, session_id)` |
| **Fees and Finance** | `fee_schedule`, `student_fee_account`, `payment (student_id, amount, date, channel)` |
| **Library System** | `library_material`, `borrowing_record`, `library_fine` |
| **Student Portal Auth** | `user_account (student_id, username, password_hash, last_login)` |
| **Additional Compulsory SE** | Set `is_compulsory_se = 1` on any course; map to all programmes in `programme_course` |

---

## 13. Developer Notes

### Key SQL Server Design Choices

| Decision | Reason |
|---|---|
| `NVARCHAR` for all text | Supports Unicode — important for Nigerian names with diacritics |
| `IDENTITY(1,1)` surrogate keys | Standard SQL Server auto-increment primary keys |
| `BIT` for boolean flags | SQL Server standard; `1 = true`, `0 = false` |
| `DATETIME2` for timestamps | Higher precision and wider range than legacy `DATETIME` |
| `AS (...) PERSISTED` on `total_score` | Computed column stored on disk for query performance |
| `CREATE OR ALTER VIEW/PROC` | Idempotent DDL — safe to re-run without dropping first |
| `GO` batch separators | Required for correct DDL execution order in SQL Server |
| Recursive CTE for `dim_date` | With `OPTION (MAXRECURSION 2000)` for the 5-year date range |
| `RETURN` in stored procedures | Clean early-exit without `RAISERROR` — keeps logic testable |
| `SET NOCOUNT ON` in all procs | Suppresses row-count messages for cleaner client output |

### Grade Scale

| Grade | Score Range | Grade Points | Remark |
|---|---|---|---|
| A | 70 – 100 | 5.0 | Excellent |
| B | 60 – 69 | 4.0 | Good |
| C | 50 – 59 | 3.0 | Average |
| D | 45 – 49 | 2.0 | Pass |
| E | 40 – 44 | 1.0 | Marginal Pass |
| F | 0 – 39 | 0.0 | Fail |

---

## Contributing

Pull requests are welcome. For major schema changes, please open an issue first to discuss the proposed design.

---

## License

MIT — free to use, modify, and distribute with attribution.

---

*LuxUniversity DB v1.0 — Microsoft SQL Server Edition*

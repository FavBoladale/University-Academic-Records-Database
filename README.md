# University-Academic-Records-Database
A fully normalized academic records management system designed using relational data modeling principles.

## Project Objective

To design and implement a structured university academic database supporting:

- Student records
- Course management
- Enrollment tracking
- Results & grading
- GPA computation

## Data Modeling Approach

This project follows:

- Conceptual Data Modeling
- Logical Data Modeling (3NF normalization)
- Physical Implementation in SQL

## Platform tested on:
- Microsoft SQL Server
- Azure SQL Database

## Database Entities
### Table	Description
- Faculties: Stores faculty information
- Departments:	Departments under the faculties
- Students:	Student biodata
- Courses:	Academic courses
- Lecturers:	Teaching staff
Enrollments:	Course registration bridge table
Results:	Student course results
GradePoints:	GPA mapping reference

## Entity Relationships
- Faculty → Department (1:N)
- Department → Student (1:N)
- Department → Course (1:N)
- Student ↔ Course (M:N resolved via Enrollments)
- Enrollment → Result (1:1)

## Features
- Fully normalized schema (3NF)
- Foreign key constraints
- Unique constraints
- Check constraints
- Computed columns
- GPA calculation support

## Analytical queries
### Sample Analytical Queries
- Top-performing students by GPA
- Department pass rate
- Course enrollment trends
- Lecturer course load
- Student academic transcript

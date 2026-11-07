# Online School Management System (OSMS)

SQL Server database implementation for the **Advanced Database Systems** course, semester **1st 2026/2027**. OSMS centralizes student records, course registrations, instructor assignments, grades, and tuition payments for an educational academy.

The repository currently contains the database schema, business rules, reports, access controls, demonstration data, and SQL tests. The web or desktop GUI and final project report required by the assignment are still to be added.

## Contents

- [Project requirements and sources](#project-requirements-and-sources)
- [Repository layout](#repository-layout)
- [Features](#features)
- [Setup and execution](#setup-and-execution)
- [Database schema](#database-schema)
- [Academic and financial rules](#academic-and-financial-rules)
- [Stored procedures](#stored-procedures)
- [Triggers](#triggers)
- [Reports](#reports)
- [Security and demo users](#security-and-demo-users)
- [Sample data](#sample-data)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Remaining assignment deliverables](#remaining-assignment-deliverables)

## Project requirements and sources

Two files define the project:

- [Rec/AdvDBProject.pdf](Rec/AdvDBProject.pdf): assignment requirements, scenario, objectives, and submission guidelines.
- [db/schema.sql](db/schema.sql): authoritative table names, column names, data types, keys, and constraints.

[db/schema.drawio](db/schema.drawio) contains two diagram pages, **Relational Schema** and **ER Diagram**, which can be opened in diagrams.net / draw.io. Keep the diagrams and supporting SQL scripts aligned with `schema.sql`.

The assignment calls for normalized relational design, a GUI with CRUD operations, automated academic rules, analytical reports, transactions, and role-based access controls. The database portion implements eight tables, six triggers, four stored procedures, four views, four inline table-valued security functions, one security policy, and three custom roles.

## Repository layout

```text
.
├── README.md
├── Rec/
│   └── AdvDBProject.pdf              # Assignment specification
└── db/
    ├── schema.sql                    # Tables, constraints, and supporting indexes
    ├── schema.drawio                 # Relational schema and ER diagram
    ├── triggers_and_procs.sql        # Academic rules, accounting, and operations
    ├── views.sql                     # Four reporting views
    ├── security.sql                  # Roles, grants, denies, and row-level security
    ├── seed.sql                      # Demo users, catalog, history, and payments
    └── sample_queries_and_tests.sql  # Report queries and behavioral checks
```

## Features

- Department, student, instructor, course, prerequisite, and section records.
- Enrollment validation for prerequisites, duplicate courses, seat capacity, and student timetable conflicts.
- Unique room and instructor schedules within each semester.
- Credit-weighted cumulative GPA recalculation when grades or relevant course credits change.
- Tuition snapshots, outstanding balances, credit after a drop, and credit reuse on re-enrollment.
- Transactional enrollment, dropping, grading, and payment procedures.
- Transcript, department, instructor workload, and unpaid tuition reports.
- Administrator, instructor, and student roles with column restrictions and row-level security (RLS).

## Setup and execution

### Prerequisites

- A running **Microsoft SQL Server** instance. The prior runtime validation used **SQL Server 2022 Developer Edition**.
- A SQL client that recognizes `GO`, such as SQL Server Management Studio (SSMS) or `sqlcmd`.
- A privileged setup connection. Using `sa` or a database owner for this local demonstration supports database creation, security setup, demo-user creation, and the impersonation tests.
- Bash for the command-line examples below. Run commands from the repository root.

These are build scripts for an **empty database**. They do not create the database, select it with `USE`, or drop existing objects. Running the entire installation twice in the same database will produce duplicate-object errors.

### 1. Configure the connection

For a SQL Server instance on the local default port:

```bash
export SQL_SERVER='localhost,1433'
export SQL_USER='sa'
read -rsp 'SQL Server password: ' SQLCMDPASSWORD
printf '\n'
export SQLCMDPASSWORD
```

Change `SQL_SERVER` and `SQL_USER` to match your instance. `sqlcmd` reads the password from `SQLCMDPASSWORD`.

The commands use `-C` to trust the server certificate for a local development connection and `-b` to return a failing exit status on SQL errors. Adjust certificate handling for your server's configuration.

### Optional: start a local SQL Server container

If you do not already have a server, use Docker after setting the variables above. Supply a password accepted by SQL Server's password policy when prompted in the previous step.

```bash
docker run -d --name osms-sqlserver \
  -e ACCEPT_EULA=Y \
  -e MSSQL_PID=Developer \
  -e "MSSQL_SA_PASSWORD=$SQLCMDPASSWORD" \
  -p 14333:1433 \
  mcr.microsoft.com/mssql/server:2022-latest

export SQL_SERVER='localhost,14333'
docker logs osms-sqlserver
```

Wait for the server log to report that SQL Server is ready for client connections. These examples still use `sqlcmd` installed on the host. This container command does not configure a persistent volume.

### 2. Create an empty database

```bash
sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -b -d master \
  -Q 'CREATE DATABASE OSMS;'
```

If `OSMS` already exists, use a new empty database name and substitute it in subsequent commands.

### 3. Run the scripts in dependency order

```bash
(
  set -e
  for script in \
    schema.sql \
    triggers_and_procs.sql \
    views.sql \
    security.sql \
    seed.sql \
    sample_queries_and_tests.sql
  do
    printf '\nRunning %s\n' "$script"
    sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -b -d OSMS \
      -i "db/$script"
  done
)
```

The subshell stops at the first failed script. The order matters: procedures and triggers depend on tables; grants depend on procedures and views; seed data depends on roles and business rules; tests depend on the seeded records.

In SSMS, create the database, select it in each query window, and execute each file separately in the same order. Preserve the existing `GO` separators around module definitions. If concatenating files manually, add a batch boundary between files so that a final procedure or view definition does not consume statements from the next file.

The final script prints five report result sets and runs the tests. After finishing the command-line session:

```bash
unset SQLCMDPASSWORD
```

## Database schema

All tables use the `dbo` schema. Every primary key below is an `INT IDENTITY(1,1)`. Columns are `NOT NULL` unless marked nullable.

### Tables and columns

| Table | Columns and SQL Server types |
| --- | --- |
| `Departments` | `DeptID INT` (PK); `DeptName NVARCHAR(100)` |
| `Instructors` | `InstructorID INT` (PK); `FullName NVARCHAR(150)`; `Email NVARCHAR(100)`; `DeptID INT` (FK) |
| `Students` | `StudentID INT` (PK); `FullName NVARCHAR(150)`; `Email NVARCHAR(100)`; `DeptID INT` (FK); `CumulativeGPA DECIMAL(3,2)`; `Balance DECIMAL(10,2)`; `CreditBalance DECIMAL(10,2)`; `EnrollmentDate DATE` |
| `Courses` | `CourseID INT` (PK); `CourseCode NVARCHAR(20)`; `CourseName NVARCHAR(150)`; `Credits INT`; `TuitionFee DECIMAL(10,2)`; `DeptID INT` (FK) |
| `CoursePrerequisites` | `PrereqID INT` (PK); `CourseID INT` (FK); `PrereqCourseID INT` (FK) |
| `Sections` | `SectionID INT` (PK); `CourseID INT` (FK); `InstructorID INT` (FK); `Semester NVARCHAR(20)`; `RoomNumber NVARCHAR(30)`; `TimeSlot NVARCHAR(50)`; `MaxCapacity INT`; `EnrolledCount INT` |
| `Enrollments` | `EnrollmentID INT` (PK); `StudentID INT` (FK); `SectionID INT` (FK); `TuitionCharged DECIMAL(10,2)`; `Grade DECIMAL(3,2)` (nullable); `Status NVARCHAR(20)`; `EnrolledAt DATETIME2` |
| `Payments` | `PaymentID INT` (PK); `StudentID INT` (FK); `Amount DECIMAL(10,2)`; `PaymentDate DATETIME2`; `PaymentMethod NVARCHAR(50)`; `TransactionReference NVARCHAR(100)` (nullable) |

### Relationships

- Each department has students, instructors, and courses.
- Each course can have multiple sections and prerequisite courses. `CoursePrerequisites` references `Courses` twice to represent the prerequisite relationship.
- Each section belongs to one course and one instructor.
- Students and sections have a many-to-many relationship through `Enrollments`.
- Each payment belongs to one student.

### Keys, constraints, defaults, and indexes

- Department names, instructor emails, student emails, and course codes are unique within their respective tables.
- Each `(CourseID, PrereqCourseID)` pair is unique; a course cannot directly require itself.
- Each `(StudentID, SectionID)` pair is unique, including historical records.
- Course credits are between 1 and 6; tuition fees and tuition snapshots are nonnegative.
- GPA and grades use the range `0.00`–`4.00`.
- `Balance` and `CreditBalance` are nonnegative; at least one must be zero.
- Section capacity is positive, and `EnrolledCount` must remain between zero and `MaxCapacity`.
- `(Semester, RoomNumber, TimeSlot)` and `(Semester, InstructorID, TimeSlot)` are unique.
- Payments must be positive and use `Cash`, `Credit Card`, or `Bank Transfer`.
- Student GPA, balance, and credit default to zero; enrollment status defaults to `Enrolled`; the initial tuition snapshot and section enrollment count default to zero.
- Student admission dates default to the current date; enrollment and payment timestamps default to `SYSDATETIME()`.
- `IX_Enrollments_Section_Status` indexes `(SectionID, Status)` and includes `StudentID, Grade`.
- `IX_Sections_Course` indexes `CourseID` and includes `InstructorID`.

## Academic and financial rules

### Enrollment and scheduling

An active enrollment requires every listed prerequisite to have a `Completed` enrollment with a grade of at least `1.00`. An existing active or completed enrollment in the same course prevents enrollment in another section of that course.

Student conflicts are checked using the same semester and exact time-slot label. Sections use these fixed, non-overlapping blocks:

```text
MW 08:30-10:00       TTh 08:30-10:00
MW 10:00-11:30       TTh 10:00-11:30
MW 11:30-13:00       TTh 11:30-13:00
MW 13:00-14:30       TTh 13:00-14:30
```

Only `Enrolled` rows occupy seats. Completing, failing, or dropping an enrollment removes it from the active count. A section with enrollment history cannot be reassigned to a different course, and section schedule changes are checked for student conflicts.

### Grades and GPA

| Enrollment status | Required grade |
| --- | --- |
| `Enrolled` | `NULL` |
| `Dropped` | `NULL` |
| `Completed` | `1.00`–`4.00` |
| `Failed` | `0.00`–less than `1.00` |

The grade procedure sets `Completed` or `Failed` automatically. GPA includes both completed and failed graded enrollments:

```text
CumulativeGPA = SUM(Grade × Credits) / SUM(Credits)
```

Students without graded history have GPA `0.00`. GPA is stored to two decimal places and recalculated after enrollment changes or relevant changes to course credits. Existing completed or failed records can be regraded, but their history cannot be changed back to active or dropped status.

The enrollment procedure reactivates a dropped row for the same section. For a failed enrollment in that section, it requires choosing another section.

### Tuition and payments

`TuitionCharged` captures the course fee when an enrollment is created or reactivated. Later fee changes do not rewrite existing charges. Dropping an active enrollment reverses its captured charge; any excess becomes `CreditBalance`. Re-enrollment captures the current fee and applies available credit before increasing the balance.

Payments cannot exceed the outstanding balance. The payment procedure inserts a payment and reduces the balance in one transaction. Use the provided procedures for application workflows so that payment records and account balances are updated together.

Enrollment ownership, section, and tuition snapshots are protected from direct rewrites. Active enrollments must be dropped before deletion, and completed/failed history is retained.

## Stored procedures

All four procedures use explicit transactions, `SET XACT_ABORT ON`, and `TRY/CATCH` rollback handling. Errors are rethrown to the caller.

| Procedure | Parameters | Behavior |
| --- | --- | --- |
| `dbo.usp_EnrollStudentInSection` | `@StudentID INT`, `@SectionID INT` | Creates an enrollment or reactivates a dropped row; triggers validate rules and maintain derived values. |
| `dbo.usp_DropStudentSection` | `@StudentID INT`, `@SectionID INT` | Drops an active enrollment, releases its seat, and reverses its tuition charge. |
| `dbo.usp_ProcessTuitionPayment` | `@StudentID INT`, `@Amount DECIMAL(10,2)`, `@PaymentMethod NVARCHAR(50)`, `@TransactionReference NVARCHAR(100) = NULL` | Records a payment and reduces the outstanding balance. |
| `dbo.usp_RecordStudentGrade` | `@StudentID INT`, `@SectionID INT`, `@Grade DECIMAL(3,2)` | Records or revises a grade, derives its status, and triggers GPA/count maintenance. |

### Example workflow

Run as `dbo` or an administrator on a freshly seeded database. This example enrolls student 6 in section 7, records a partial payment, and completes the course. It changes the seed state, so run the built-in tests before experimenting.

```sql
EXEC dbo.usp_EnrollStudentInSection
    @StudentID = 6, @SectionID = 7;

EXEC dbo.usp_ProcessTuitionPayment
    @StudentID = 6,
    @Amount = 500.00,
    @PaymentMethod = N'Cash';

EXEC dbo.usp_RecordStudentGrade
    @StudentID = 6, @SectionID = 7, @Grade = 3.50;

SELECT StudentID, FullName, CumulativeGPA, Balance, CreditBalance
FROM dbo.Students
WHERE StudentID = 6;
```

To drop an enrollment instead, call `usp_DropStudentSection` while its status is still `Enrolled`.

### Application error codes

| Error | Meaning |
| --- | --- |
| `50001` | A required prerequisite has not been completed. |
| `50002` | Section capacity would be exceeded. |
| `50003` | The required enrollment was not found or is not eligible for the operation. |
| `50004` | Payment exceeds the outstanding balance. |
| `50005` | Student not found. |
| `50006` | Section not found. |
| `50007` | Payment amount is null or nonpositive. |
| `50008` | The student is already enrolled in or has completed this section. |
| `50009` | The student is already enrolled in or has completed the course in another section. |
| `50010` | A failed enrollment already exists for this section. |
| `50011` | The caller attempted to manage another student's account. |
| `50012` | Enrollment deletion would remove active or completed/failed history. |
| `50013` | A protected enrollment field or status transition was changed. |
| `50014` | A section with enrollment history was reassigned to another course. |
| `50016` | A student timetable conflict was introduced. |
| `50017` | The caller is not the assigned instructor or an administrator for grading. |
| `50018` | Grade is null or outside `0.00`–`4.00`. |

Constraints, permissions, and RLS can also raise SQL Server errors, such as `547`, `2601`/`2627`, `230`, and `33504`.

## Triggers

The triggers execute as the owner so that internal checks and maintenance can access the required records despite caller-level row restrictions.

| Trigger | Purpose |
| --- | --- |
| `trg_Enrollments_CheckPrerequisites` | Checks prerequisites, duplicate courses, and student timetable conflicts on insert/update. |
| `trg_Enrollments_EnforceCapacity` | Rejects over-capacity enrollment and recalculates active section counts. |
| `trg_Enrollments_RecalculateGPA` | Recalculates affected students' credit-weighted GPA. |
| `trg_Enrollments_MaintainTuition` | Captures tuition, applies charge changes, maintains balances/credit, and protects enrollment history. |
| `trg_Sections_ProtectCourseHistory` | Protects course assignments and checks student conflicts after section changes. |
| `trg_Courses_RecalculateGPA` | Recalculates affected GPAs when course credits change. |

## Reports

| View | Output |
| --- | --- |
| `dbo.vw_StudentTranscript` | Student, department, course, semester, schedule, credits, grade, status, and cumulative GPA for enrollment records. |
| `dbo.vw_DepartmentEnrollmentStats` | Student totals, active course enrollments, active credits, and average GPA grouped by the student's department. |
| `dbo.vw_InstructorTeachingLoad` | Section/course counts, credit hours, active enrollment counts, and schedules per instructor and semester. |
| `dbo.vw_UnpaidTuitionAccounts` | Students with a positive balance, total payments, and last payment date. |

The transcript includes active, dropped, completed, and failed records. The department GPA average includes students whose GPA is zero. Teaching-load enrollment totals count section enrollments rather than distinct students.

Example report queries, run as an administrator:

```sql
SELECT * FROM dbo.vw_StudentTranscript
WHERE StudentID = 1;

SELECT * FROM dbo.vw_DepartmentEnrollmentStats
ORDER BY DeptID;

SELECT * FROM dbo.vw_InstructorTeachingLoad
ORDER BY InstructorID, Semester;

SELECT * FROM dbo.vw_UnpaidTuitionAccounts
ORDER BY OutstandingBalance DESC;
```

The sample-query script also joins the course catalog to its immediate prerequisite courses.

## Security and demo users

### Role permissions

| Role | Access |
| --- | --- |
| `AdminRole` | CRUD on all eight tables, access to all four reports, and execution of all four procedures. |
| `InstructorRole` | Catalog/schedule reads, academic profiles of students in assigned sections, assigned-section enrollment rows, transcript and own teaching-load reports, and grading. Student financial columns and payment records are denied. |
| `StudentRole` | Catalog/schedule reads, the student's own profile, enrollments, payments and transcript, plus enrollment/drop/payment procedures. Direct table writes and grade-procedure execution are denied. |

### Row-level security

`dbo.OSMS_RecordAccess` applies filter and block predicates using these inline table-valued functions:

- `fn_EnrollmentAccess`: identifies visible/accessible enrollment rows.
- `fn_EnrollmentUpdateAccess`: restricts enrollment updates by caller identity and resulting status.
- `fn_StudentAccountAccess`: restricts payment visibility and insertion to the account owner or administrators.
- `fn_StudentProfileAccess`: exposes the student's own profile or profiles connected to an instructor's sections.

The policy uses database principal names and role membership. Student names must match `Student_<StudentID>`; instructor names must match `Instructor_<InstructorID>`. `dbo` and members of `AdminRole` have broad access through these predicates. The teaching-load view also filters instructors to their own rows.

### Seeded principals

`seed.sql` creates these database users **WITHOUT LOGIN**:

- `Admin_1` in `AdminRole`.
- `Instructor_1` through `Instructor_4` in `InstructorRole`.
- `Student_1` through `Student_6` in `StudentRole`.

They support impersonation demonstrations; they are not server login credentials. A future GUI must provision database identities or a suitable authentication design consistent with these checks. Passing a student ID as a procedure parameter does not by itself establish the caller's identity.

From a privileged database session, inspect student isolation with:

```sql
EXECUTE AS USER = N'Student_1';
SELECT StudentID, FullName, Balance, CreditBalance FROM dbo.Students;
SELECT * FROM dbo.vw_StudentTranscript;
REVERT;
```

For an instructor, select academic columns explicitly: `SELECT * FROM dbo.Students` includes denied financial columns and will fail.

## Sample data

The seed creates 3 departments, 4 instructors, 6 students, 6 courses, 4 prerequisite pairs, 7 sections, 16 enrollment records, and 4 payments totaling **12,100.00**. Enrollment history is established through the stored procedures so that GPA, seat counts, and balances are calculated by the implementation.

The prerequisite relationships are:

```text
CS201   requires CS101 and MATH101
CS301   requires CS201
STAT205 requires MATH101
```

Section 4 (`CS301`, Fall 2026) has capacity 2 and is full after seeding, providing the capacity-test fixture. Student 6 initially has no enrollments.

Expected account state immediately after seeding:

| StudentID | FullName | CumulativeGPA | Balance | CreditBalance |
| --- | --- | --- | --- | --- |
| 1 | Omar Al-Harbi | 3.75 | 2050.00 | 0.00 |
| 2 | Sara Al-Qahtani | 3.60 | 0.00 | 0.00 |
| 3 | Youssef Kamel | 1.65 | 2150.00 | 0.00 |
| 4 | Mariam Nasser | 0.00 | 2550.00 | 0.00 |
| 5 | Ziad Al-Otaibi | 3.20 | 2350.00 | 0.00 |
| 6 | Hana Suleiman | 0.00 | 0.00 | 0.00 |

## Testing

Run [db/sample_queries_and_tests.sql](db/sample_queries_and_tests.sql) after all other scripts, from a privileged connection against the seeded database. It contains eight numbered test groups and **12 success messages**, including subtests:

| Test | Expected behavior |
| --- | --- |
| 1 | Reject an unmet/failed prerequisite (`50001`). |
| 2 | Reject enrollment beyond section capacity (`50002`). |
| 3 | Reject duplicate course enrollment across sections (`50009`). |
| 4 | Reject a student timetable conflict (`50016`). |
| 5a / 5b | Reject room and instructor double-booking (`2601` or `2627`). |
| 6 | Reject a completed enrollment with a failing grade (`547`). |
| 7 | Preserve the tuition snapshot when dropping, create credit, and reuse it at the current fee on re-enrollment. |
| 8a | Enforce student row isolation and reject management of another student (`50011`). |
| 8b | Deny instructors access to financial columns (`230`). |
| 8c | Reject grading another instructor's section (`50017`). |
| 8d | Block an instructor from directly dropping an enrollment (`33504`). |

Expected errors are caught and checked. Unexpected behavior is rethrown, including custom `59999` test failures, so use `sqlcmd -b` to detect failure. Successful transactional test changes are rolled back; identity counters may still advance. Use a fresh seed state for reproducible runs, and do not run the suite against application data.

Prior runtime validation on **2026-11-07** executed all six SQL files successfully on a fresh SQL Server 2022 Developer Edition database and produced all 12 success messages. That validates the supplied demonstration scenarios; it does not constitute GUI or multi-session load testing.

In that run, the SQL client omitted a leading `[PASS]` from `PRINT` output. A success line could therefore appear as `Test 1: ...` without the marker. Check the complete output and process exit status.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Database `OSMS` does not exist | Create it before running the scripts. |
| An object already exists | Use an empty database; these scripts are not idempotent migrations. |
| Invalid object name or missing role | Check the selected database and installation order. |
| `CREATE VIEW` / `CREATE PROCEDURE` must be first in a batch | Execute the files separately with a client that recognizes `GO`; retain module batch boundaries. |
| Literal `GO` causes a syntax error in an application | Split script batches in the application runner; `GO` is handled by SQL clients, not sent as T-SQL. |
| Demo user cannot log in | Seed users are `WITHOUT LOGIN`; use privileged `EXECUTE AS USER` for demonstrations. |
| Instructor profile query fails | Select permitted academic columns explicitly and omit `Balance` and `CreditBalance`. |
| Student queries show fewer rows | RLS intentionally limits the current database principal's visibility. |
| Tests fail after manual changes | Run against a fresh installation with the supplied seed data. |

## Remaining assignment deliverables

The PDF requires a GUI supporting CRUD workflows for administrators, instructors, and students, along with screenshots/wireframes and a final report. These artifacts are not yet included in this repository.

Organize the final report using the assignment's sections:

1. Title page: project title, student names and IDs, course, instructor, and date.
2. Problem statement.
3. General and advanced database objectives.
4. System analysis: users, requirements, and data flow.
5. ER diagram and relationship explanations.
6. Database design: tables, constraints, and relationships.
7. GUI design, screenshots, or wireframes.
8. Implementation tools used for the database and GUI.

Also include the sample queries and testing results requested in the project description. Submission is one PDF with figures embedded, completed by a team of **2–4 students**. The assignment states that submission and presentations begin after **15 November 2026**; consult the source PDF for the exact wording.

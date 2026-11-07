CREATE USER Admin_1 WITHOUT LOGIN;
CREATE USER Instructor_1 WITHOUT LOGIN;
CREATE USER Instructor_2 WITHOUT LOGIN;
CREATE USER Instructor_3 WITHOUT LOGIN;
CREATE USER Instructor_4 WITHOUT LOGIN;
CREATE USER Student_1 WITHOUT LOGIN;
CREATE USER Student_2 WITHOUT LOGIN;
CREATE USER Student_3 WITHOUT LOGIN;
CREATE USER Student_4 WITHOUT LOGIN;
CREATE USER Student_5 WITHOUT LOGIN;
CREATE USER Student_6 WITHOUT LOGIN;

ALTER ROLE AdminRole ADD MEMBER Admin_1;
ALTER ROLE InstructorRole ADD MEMBER Instructor_1;
ALTER ROLE InstructorRole ADD MEMBER Instructor_2;
ALTER ROLE InstructorRole ADD MEMBER Instructor_3;
ALTER ROLE InstructorRole ADD MEMBER Instructor_4;
ALTER ROLE StudentRole ADD MEMBER Student_1;
ALTER ROLE StudentRole ADD MEMBER Student_2;
ALTER ROLE StudentRole ADD MEMBER Student_3;
ALTER ROLE StudentRole ADD MEMBER Student_4;
ALTER ROLE StudentRole ADD MEMBER Student_5;
ALTER ROLE StudentRole ADD MEMBER Student_6;

SET IDENTITY_INSERT dbo.Departments ON;
INSERT INTO dbo.Departments (DeptID, DeptName)
VALUES
    (1, N'Computer Science'),
    (2, N'Information Systems'),
    (3, N'Mathematics & Data Science');
SET IDENTITY_INSERT dbo.Departments OFF;

SET IDENTITY_INSERT dbo.Instructors ON;
INSERT INTO dbo.Instructors (InstructorID, FullName, Email, DeptID)
VALUES
    (1, N'Dr. Tariq Al-Mansoor', N'tariq.mansoor@osms.edu', 1),
    (2, N'Dr. Nadia El-Sayed',   N'nadia.elsayed@osms.edu', 1),
    (3, N'Prof. Kareem Haddad',  N'kareem.haddad@osms.edu', 2),
    (4, N'Dr. Laila Farooq',     N'laila.farooq@osms.edu',  3);
SET IDENTITY_INSERT dbo.Instructors OFF;

SET IDENTITY_INSERT dbo.Students ON;
INSERT INTO dbo.Students (StudentID, FullName, Email, DeptID, EnrollmentDate)
VALUES
    (1, N'Omar Al-Harbi',   N'omar.harbi@student.osms.edu',   1, '2025-09-01'),
    (2, N'Sara Al-Qahtani', N'sara.qahtani@student.osms.edu', 1, '2025-09-01'),
    (3, N'Youssef Kamel',   N'youssef.kamel@student.osms.edu', 2, '2025-09-01'),
    (4, N'Mariam Nasser',   N'mariam.nasser@student.osms.edu', 2, '2026-01-15'),
    (5, N'Ziad Al-Otaibi',  N'ziad.otaibi@student.osms.edu',  3, '2026-01-15'),
    (6, N'Hana Suleiman',   N'hana.suleiman@student.osms.edu', 1, '2026-09-01');
SET IDENTITY_INSERT dbo.Students OFF;

SET IDENTITY_INSERT dbo.Courses ON;
INSERT INTO dbo.Courses (CourseID, CourseCode, CourseName, Credits, TuitionFee, DeptID)
VALUES
    (1, N'CS101',   N'Introduction to Programming',      3, 1200.00, 1),
    (2, N'CS201',   N'Data Structures & Algorithms',     4, 1600.00, 1),
    (3, N'CS301',   N'Advanced Database Systems',        4, 1800.00, 1),
    (4, N'IS210',   N'Enterprise Systems Architecture',  3, 1350.00, 2),
    (5, N'MATH101', N'Discrete Mathematics',             3, 1100.00, 3),
    (6, N'STAT205', N'Probability & Statistical Models', 3, 1250.00, 3);
SET IDENTITY_INSERT dbo.Courses OFF;

INSERT INTO dbo.CoursePrerequisites (CourseID, PrereqCourseID)
VALUES
    (2, 1),
    (2, 5),
    (3, 2),
    (6, 5);

SET IDENTITY_INSERT dbo.Sections ON;
INSERT INTO dbo.Sections (SectionID, CourseID, InstructorID, Semester, RoomNumber, TimeSlot, MaxCapacity)
VALUES
    (1, 1, 1, N'Fall 2025',   N'Bldg-A 101', N'MW 08:30-10:00',  30),
    (2, 5, 4, N'Fall 2025',   N'Bldg-C 204', N'TTh 10:00-11:30', 30),
    (3, 2, 2, N'Spring 2026', N'Bldg-A 102', N'MW 10:00-11:30',  25),
    (4, 3, 1, N'Fall 2026',   N'Lab-DB 301', N'MW 10:00-11:30',   2),
    (5, 4, 3, N'Fall 2026',   N'Bldg-B 110', N'TTh 08:30-10:00', 25),
    (6, 6, 4, N'Fall 2026',   N'Bldg-C 204', N'MW 11:30-13:00',  20),
    (7, 1, 2, N'Fall 2026',   N'Bldg-A 105', N'MW 10:00-11:30',  30);
SET IDENTITY_INSERT dbo.Sections OFF;

EXEC dbo.usp_EnrollStudentInSection @StudentID = 1, @SectionID = 1;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 1, @SectionID = 1, @Grade = 3.80;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 1, @SectionID = 2;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 1, @SectionID = 2, @Grade = 3.50;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 1, @SectionID = 3;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 1, @SectionID = 3, @Grade = 3.90;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 1, @SectionID = 4;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 1, @SectionID = 6;

EXEC dbo.usp_EnrollStudentInSection @StudentID = 2, @SectionID = 1;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 2, @SectionID = 1, @Grade = 3.60;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 2, @SectionID = 2;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 2, @SectionID = 2, @Grade = 3.40;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 2, @SectionID = 3;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 2, @SectionID = 3, @Grade = 3.75;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 2, @SectionID = 4;

EXEC dbo.usp_EnrollStudentInSection @StudentID = 3, @SectionID = 1;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 3, @SectionID = 1, @Grade = 2.80;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 3, @SectionID = 2;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 3, @SectionID = 2, @Grade = 0.50;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 3, @SectionID = 5;

EXEC dbo.usp_EnrollStudentInSection @StudentID = 4, @SectionID = 5;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 4, @SectionID = 7;

EXEC dbo.usp_EnrollStudentInSection @StudentID = 5, @SectionID = 2;
EXEC dbo.usp_RecordStudentGrade     @StudentID = 5, @SectionID = 2, @Grade = 3.20;
EXEC dbo.usp_EnrollStudentInSection @StudentID = 5, @SectionID = 6;

EXEC dbo.usp_ProcessTuitionPayment
    @StudentID = 1, @Amount = 3900.00,
    @PaymentMethod = N'Bank Transfer', @TransactionReference = N'TRX-2026-0001';
EXEC dbo.usp_ProcessTuitionPayment
    @StudentID = 1, @Amount = 1000.00,
    @PaymentMethod = N'Credit Card',   @TransactionReference = N'TRX-2026-0002';

EXEC dbo.usp_ProcessTuitionPayment
    @StudentID = 2, @Amount = 5700.00,
    @PaymentMethod = N'Bank Transfer', @TransactionReference = N'TRX-2026-0003';

EXEC dbo.usp_ProcessTuitionPayment
    @StudentID = 3, @Amount = 1500.00,
    @PaymentMethod = N'Cash',          @TransactionReference = NULL;

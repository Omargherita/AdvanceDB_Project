-- 1. Student Transcript Summary Report
SELECT StudentID, FullName, DeptName, CourseCode, CourseName,
       Semester, RoomNumber, TimeSlot, Credits, Grade, Status, CumulativeGPA
FROM dbo.vw_StudentTranscript
ORDER BY StudentID, Semester, CourseCode;

-- 2. Department Enrollment & GPA Statistics Report
SELECT DeptID, DeptName, TotalStudents, ActiveCourseEnrollments,
       TotalCreditsEnrolled, AverageDepartmentGPA
FROM dbo.vw_DepartmentEnrollmentStats
ORDER BY DeptID;

-- 3. Instructor Teaching Load Report
SELECT InstructorID, FullName, DeptName, Semester, Schedules,
       AssignedSectionsCount, DistinctCoursesCount, TotalCreditHours, TotalEnrolledStudents
FROM dbo.vw_InstructorTeachingLoad
ORDER BY InstructorID, Semester;

-- 4. Unpaid Tuition Accounts Report
SELECT StudentID, FullName, Email, DeptName,
       OutstandingBalance, TotalPaidToDate, LastPaymentDate
FROM dbo.vw_UnpaidTuitionAccounts
ORDER BY OutstandingBalance DESC, StudentID;

-- 5. Course Catalog with Prerequisite Chains
SELECT C.CourseCode, C.CourseName, C.Credits, C.TuitionFee, D.DeptName,
       COALESCE(STRING_AGG(P.CourseCode, N', ') WITHIN GROUP (ORDER BY P.CourseCode), N'None') AS Prerequisites
FROM dbo.Courses AS C
INNER JOIN dbo.Departments AS D ON D.DeptID = C.DeptID
LEFT JOIN dbo.CoursePrerequisites AS CP ON CP.CourseID = C.CourseID
LEFT JOIN dbo.Courses AS P ON P.CourseID = CP.PrereqCourseID
GROUP BY C.CourseID, C.CourseCode, C.CourseName, C.Credits, C.TuitionFee, D.DeptName
ORDER BY C.CourseCode;

-- Test 1: Prerequisite Enforcement (Error 50001)
BEGIN TRY
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 3, @SectionID = 6;
    THROW 59999, 'TEST FAILED: Expected 50001 prerequisite error was not thrown.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50001
        THROW;
    PRINT '[PASS] Test 1: Prerequisite check rejected enrollment with unmet/failed prerequisite (50001).';
END CATCH;

-- Test 2: Classroom Capacity Enforcement (Error 50002)
BEGIN TRY
    BEGIN TRANSACTION;
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 5, @SectionID = 1;
    EXEC dbo.usp_RecordStudentGrade     @StudentID = 5, @SectionID = 1, @Grade = 3.50;
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 5, @SectionID = 3;
    EXEC dbo.usp_RecordStudentGrade     @StudentID = 5, @SectionID = 3, @Grade = 3.60;
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 5, @SectionID = 4;
    THROW 59999, 'TEST FAILED: Expected 50002 capacity error was not thrown.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50002
        THROW;
    PRINT '[PASS] Test 2: Classroom capacity trigger rejected over-enrollment on full section (50002).';
END CATCH;

-- Test 3: Duplicate Course Prevention Across Sections (Error 50009)
BEGIN TRY
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 1, @SectionID = 7;
    THROW 59999, 'TEST FAILED: Expected 50009 duplicate course error was not thrown.', 1;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() <> 50009
        THROW;
    PRINT '[PASS] Test 3: Duplicate course check rejected re-enrollment in already completed course (50009).';
END CATCH;

-- Test 4: Student Timetable Conflict Prevention (Error 50016)
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Sections (CourseID, InstructorID, Semester, RoomNumber, TimeSlot, MaxCapacity)
    VALUES (5, 4, N'Fall 2026', N'Bldg-C 205', N'MW 10:00-11:30', 20);
    DECLARE @ConflictSectionID INT = SCOPE_IDENTITY();

    EXEC dbo.usp_EnrollStudentInSection @StudentID = 6, @SectionID = 7;
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 6, @SectionID = @ConflictSectionID;
    THROW 59999, 'TEST FAILED: Expected 50016 timetable conflict error was not thrown.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 50016
        THROW;
    PRINT '[PASS] Test 4: Timetable conflict trigger rejected overlapping student schedule (50016).';
END CATCH;

-- Test 5: Room & Instructor Double-Booking Constraints
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Sections (CourseID, InstructorID, Semester, RoomNumber, TimeSlot, MaxCapacity)
    VALUES (5, 4, N'Fall 2026', N'Lab-DB 301', N'MW 10:00-11:30', 20);
    THROW 59999, 'TEST FAILED: Expected UQ_Sections_RoomSchedule violation was not thrown.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (2601, 2627)
        THROW;
    PRINT '[PASS] Test 5a: UQ_Sections_RoomSchedule prevented classroom double-booking.';
END CATCH;

BEGIN TRY
    BEGIN TRANSACTION;
    INSERT INTO dbo.Sections (CourseID, InstructorID, Semester, RoomNumber, TimeSlot, MaxCapacity)
    VALUES (1, 1, N'Fall 2026', N'Bldg-A 999', N'MW 10:00-11:30', 20);
    THROW 59999, 'TEST FAILED: Expected UQ_Sections_InstructorSchedule violation was not thrown.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() NOT IN (2601, 2627)
        THROW;
    PRINT '[PASS] Test 5b: UQ_Sections_InstructorSchedule prevented instructor double-booking.';
END CATCH;

-- Test 6: Grade-to-Status Coherence Constraint (CHK_Enrollments_GradeStatus)
BEGIN TRY
    BEGIN TRANSACTION;
    UPDATE dbo.Enrollments
    SET Status = N'Completed', Grade = 0.50
    WHERE StudentID = 1 AND SectionID = 4;
    THROW 59999, 'TEST FAILED: Expected CHK_Enrollments_GradeStatus violation was not thrown.', 1;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 547
        THROW;
    PRINT '[PASS] Test 6: CHK_Enrollments_GradeStatus blocked Completed status with failing grade (< 1.00).';
END CATCH;

-- Test 7: Tuition Snapshot, Drop Refund to CreditBalance & Re-Enrollment Reuse
BEGIN TRANSACTION;
    UPDATE dbo.Courses SET TuitionFee = 2200.00 WHERE CourseID = 3;
    EXEC dbo.usp_DropStudentSection @StudentID = 2, @SectionID = 4;

    DECLARE @Bal DECIMAL(10,2), @Cred DECIMAL(10,2), @Seats INT;
    SELECT @Bal = Balance, @Cred = CreditBalance FROM dbo.Students WHERE StudentID = 2;
    SELECT @Seats = EnrolledCount FROM dbo.Sections WHERE SectionID = 4;

    IF @Bal <> 0.00 OR @Cred <> 1800.00 OR @Seats <> 1
        THROW 59999, 'TEST FAILED: Drop refund snapshot or seat decrement mismatch.', 1;

    EXEC dbo.usp_EnrollStudentInSection @StudentID = 2, @SectionID = 4;
    SELECT @Bal = Balance, @Cred = CreditBalance FROM dbo.Students WHERE StudentID = 2;
    SELECT @Seats = EnrolledCount FROM dbo.Sections WHERE SectionID = 4;

    IF @Bal <> 400.00 OR @Cred <> 0.00 OR @Seats <> 2
        THROW 59999, 'TEST FAILED: Re-enrollment credit reuse or seat increment mismatch.', 1;
ROLLBACK TRANSACTION;
PRINT '[PASS] Test 7: Tuition snapshot, credit refund on drop, and credit reuse on re-enrollment verified.';

-- Test 8: RBAC & Row-Level Security Isolation for StudentRole and InstructorRole
DECLARE @VisibleStudents INT, @VisibleEnrollments INT, @VisiblePayments INT;

EXECUTE AS USER = N'Student_1';
    SELECT @VisibleStudents = COUNT(*) FROM dbo.Students;
    SELECT @VisibleEnrollments = COUNT(*) FROM dbo.Enrollments WHERE StudentID <> 1;
    SELECT @VisiblePayments = COUNT(*) FROM dbo.Payments WHERE StudentID <> 1;
    IF @VisibleStudents <> 1 OR @VisibleEnrollments <> 0 OR @VisiblePayments <> 0
    BEGIN
        REVERT;
        THROW 59999, 'TEST FAILED: Student_1 observed another student''s records.', 1;
    END;
REVERT;

BEGIN TRY
    EXECUTE AS USER = N'Student_1';
    EXEC dbo.usp_EnrollStudentInSection @StudentID = 2, @SectionID = 5;
    REVERT;
    THROW 59999, 'TEST FAILED: Student_1 managed Student_2''s enrollment.', 1;
END TRY
BEGIN CATCH
    REVERT;
    IF ERROR_NUMBER() <> 50011
        THROW;
    PRINT '[PASS] Test 8a: StudentRole RLS isolation and cross-student procedure guard (50011) verified.';
END CATCH;

EXECUTE AS USER = N'Instructor_1';
    DECLARE @InstCount INT, @PrereqCount INT, @LoadRows INT;
    SELECT @InstCount = COUNT(*) FROM dbo.Instructors;
    SELECT @PrereqCount = COUNT(*) FROM dbo.CoursePrerequisites;
    SELECT @LoadRows = COUNT(*) FROM dbo.vw_InstructorTeachingLoad WHERE InstructorID <> 1;
    IF @InstCount = 0 OR @PrereqCount = 0 OR @LoadRows <> 0
    BEGIN
        REVERT;
        THROW 59999, 'TEST FAILED: Instructor_1 catalog read or teaching-load isolation failed.', 1;
    END;
REVERT;

BEGIN TRY
    EXECUTE AS USER = N'Instructor_1';
    DECLARE @LeakedBalance DECIMAL(10,2);
    SELECT TOP (1) @LeakedBalance = Balance FROM dbo.Students;
    REVERT;
    THROW 59999, 'TEST FAILED: Instructor_1 was able to read Students.Balance.', 1;
END TRY
BEGIN CATCH
    REVERT;
    IF ERROR_NUMBER() <> 230
        THROW;
    PRINT '[PASS] Test 8b: InstructorRole blocked from reading student financial columns (Balance/CreditBalance).';
END CATCH;

BEGIN TRY
    EXECUTE AS USER = N'Instructor_1';
    EXEC dbo.usp_RecordStudentGrade @StudentID = 3, @SectionID = 5, @Grade = 3.00;
    REVERT;
    THROW 59999, 'TEST FAILED: Instructor_1 graded another instructor''s section.', 1;
END TRY
BEGIN CATCH
    REVERT;
    IF ERROR_NUMBER() <> 50017
        THROW;
    PRINT '[PASS] Test 8c: InstructorRole blocked from grading another instructor''s section (50017).';
END CATCH;

BEGIN TRY
    BEGIN TRANSACTION;
    EXECUTE AS USER = N'Instructor_1';
    UPDATE dbo.Enrollments
    SET Status = N'Dropped', Grade = NULL
    WHERE StudentID = 1 AND SectionID = 4;
    REVERT;
    THROW 59999, 'TEST FAILED: Instructor_1 was able to drop a student directly.', 1;
END TRY
BEGIN CATCH
    REVERT;
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    IF ERROR_NUMBER() <> 33504
        THROW;
    PRINT '[PASS] Test 8d: RLS block predicate prevented InstructorRole from setting Status = Dropped (33504).';
END CATCH;

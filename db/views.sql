CREATE VIEW dbo.vw_StudentTranscript
AS
    SELECT ST.StudentID, ST.FullName, D.DeptName,
           C.CourseCode, C.CourseName, S.Semester, S.RoomNumber, S.TimeSlot, C.Credits,
           E.Grade, E.Status, ST.CumulativeGPA
    FROM dbo.Students AS ST
    INNER JOIN dbo.Departments AS D ON D.DeptID = ST.DeptID
    INNER JOIN dbo.Enrollments AS E ON E.StudentID = ST.StudentID
    INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
    INNER JOIN dbo.Courses AS C ON C.CourseID = S.CourseID;
GO

CREATE VIEW dbo.vw_DepartmentEnrollmentStats
AS
    WITH StudentStats AS
    (
        SELECT DeptID,
               COUNT(*) AS TotalStudents,
               AVG(CumulativeGPA) AS AverageDepartmentGPA
        FROM dbo.Students
        GROUP BY DeptID
    ),
    ActiveStats AS
    (
        SELECT ST.DeptID,
               COUNT(*) AS ActiveCourseEnrollments,
               SUM(C.Credits) AS TotalCreditsEnrolled
        FROM dbo.Students AS ST
        INNER JOIN dbo.Enrollments AS E ON E.StudentID = ST.StudentID
        INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
        INNER JOIN dbo.Courses AS C ON C.CourseID = S.CourseID
        WHERE E.Status = N'Enrolled'
        GROUP BY ST.DeptID
    )
    SELECT D.DeptID, D.DeptName,
           COALESCE(ST.TotalStudents, 0) AS TotalStudents,
           COALESCE(A.ActiveCourseEnrollments, 0) AS ActiveCourseEnrollments,
           COALESCE(A.TotalCreditsEnrolled, 0) AS TotalCreditsEnrolled,
           CAST(COALESCE(ST.AverageDepartmentGPA, 0.00) AS DECIMAL(3,2)) AS AverageDepartmentGPA
    FROM dbo.Departments AS D
    LEFT JOIN StudentStats AS ST ON ST.DeptID = D.DeptID
    LEFT JOIN ActiveStats AS A ON A.DeptID = D.DeptID;
GO

CREATE VIEW dbo.vw_InstructorTeachingLoad
AS
    SELECT I.InstructorID, I.FullName, D.DeptName, S.Semester,
           STRING_AGG(S.RoomNumber + N' / ' + S.TimeSlot, N'; ')
               WITHIN GROUP (ORDER BY S.SectionID) AS Schedules,
           COUNT(S.SectionID) AS AssignedSectionsCount,
           COUNT(DISTINCT S.CourseID) AS DistinctCoursesCount,
           COALESCE(SUM(C.Credits), 0) AS TotalCreditHours,
           COALESCE(SUM(S.EnrolledCount), 0) AS TotalEnrolledStudents
    FROM dbo.Instructors AS I
    INNER JOIN dbo.Departments AS D ON D.DeptID = I.DeptID
    LEFT JOIN dbo.Sections AS S ON S.InstructorID = I.InstructorID
    LEFT JOIN dbo.Courses AS C ON C.CourseID = S.CourseID
    WHERE USER_NAME() = N'dbo' OR IS_MEMBER(N'AdminRole') = 1
       OR USER_NAME() = CONCAT(N'Instructor_', I.InstructorID)
    GROUP BY I.InstructorID, I.FullName, D.DeptName, S.Semester;
GO

CREATE VIEW dbo.vw_UnpaidTuitionAccounts
AS
    WITH PaymentTotals AS
    (
        SELECT StudentID,
               SUM(Amount) AS TotalPaidToDate,
               MAX(PaymentDate) AS LastPaymentDate
        FROM dbo.Payments
        GROUP BY StudentID
    )
    SELECT ST.StudentID, ST.FullName, ST.Email, D.DeptName,
           ST.Balance AS OutstandingBalance,
           COALESCE(P.TotalPaidToDate, 0.00) AS TotalPaidToDate,
           P.LastPaymentDate
    FROM dbo.Students AS ST
    INNER JOIN dbo.Departments AS D ON D.DeptID = ST.DeptID
    LEFT JOIN PaymentTotals AS P ON P.StudentID = ST.StudentID
    WHERE ST.Balance > 0.00;

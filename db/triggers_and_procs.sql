CREATE TRIGGER dbo.trg_Enrollments_CheckPrerequisites
ON dbo.Enrollments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS I
        INNER JOIN dbo.Sections AS S ON S.SectionID = I.SectionID
        INNER JOIN dbo.Enrollments AS E
            ON E.StudentID = I.StudentID AND E.EnrollmentID <> I.EnrollmentID
        INNER JOIN dbo.Sections AS ES ON ES.SectionID = E.SectionID
        WHERE I.Status = N'Enrolled'
          AND ES.CourseID = S.CourseID
          AND E.Status IN (N'Enrolled', N'Completed')
    )
        THROW 50009, 'Enrollment denied: Student is already enrolled in or has completed this course in another section.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS I
        INNER JOIN dbo.Sections AS S ON S.SectionID = I.SectionID
        INNER JOIN dbo.Enrollments AS E
            ON E.StudentID = I.StudentID AND E.EnrollmentID <> I.EnrollmentID
        INNER JOIN dbo.Sections AS ES ON ES.SectionID = E.SectionID
        WHERE I.Status = N'Enrolled'
          AND E.Status = N'Enrolled'
          AND ES.Semester = S.Semester
          AND ES.TimeSlot = S.TimeSlot
    )
        THROW 50016, 'Enrollment denied: Student has a timetable conflict in the same semester and time slot.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS I
        INNER JOIN dbo.Sections AS S ON S.SectionID = I.SectionID
        INNER JOIN dbo.CoursePrerequisites AS P ON P.CourseID = S.CourseID
        WHERE I.Status = N'Enrolled'
          AND NOT EXISTS
          (
              SELECT 1
              FROM dbo.Enrollments AS E
              INNER JOIN dbo.Sections AS PS ON PS.SectionID = E.SectionID
              WHERE E.StudentID = I.StudentID
                AND PS.CourseID = P.PrereqCourseID
                AND E.Status = N'Completed'
                AND E.Grade >= 1.00
          )
    )
        THROW 50001, 'Enrollment denied: Student has not completed all required prerequisite courses.', 1;
END;
GO

CREATE TRIGGER dbo.trg_Enrollments_EnforceCapacity
ON dbo.Enrollments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM dbo.Sections AS S
        INNER JOIN (SELECT SectionID FROM inserted UNION SELECT SectionID FROM deleted) AS A
            ON A.SectionID = S.SectionID
        WHERE (SELECT COUNT(*) FROM dbo.Enrollments AS E
               WHERE E.SectionID = S.SectionID AND E.Status = N'Enrolled') > S.MaxCapacity
    )
        THROW 50002, 'Enrollment denied: Classroom section has reached maximum capacity.', 1;

    UPDATE S
    SET EnrolledCount =
        (SELECT COUNT(*) FROM dbo.Enrollments AS E
         WHERE E.SectionID = S.SectionID AND E.Status = N'Enrolled')
    FROM dbo.Sections AS S
    INNER JOIN (SELECT SectionID FROM inserted UNION SELECT SectionID FROM deleted) AS A
        ON A.SectionID = S.SectionID;
END;
GO

CREATE TRIGGER dbo.trg_Enrollments_RecalculateGPA
ON dbo.Enrollments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    WITH AffectedStudents AS
    (
        SELECT StudentID FROM inserted
        UNION
        SELECT StudentID FROM deleted
    ),
    GradeTotals AS
    (
        SELECT E.StudentID,
               SUM(E.Grade * C.Credits) / NULLIF(SUM(C.Credits), 0) AS GPA
        FROM dbo.Enrollments AS E
        INNER JOIN AffectedStudents AS A ON A.StudentID = E.StudentID
        INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
        INNER JOIN dbo.Courses AS C ON C.CourseID = S.CourseID
        WHERE E.Grade IS NOT NULL
          AND E.Status IN (N'Completed', N'Failed')
        GROUP BY E.StudentID
    )
    UPDATE ST
    SET CumulativeGPA = CAST(COALESCE(G.GPA, 0.00) AS DECIMAL(3,2))
    FROM dbo.Students AS ST
    INNER JOIN AffectedStudents AS A ON A.StudentID = ST.StudentID
    LEFT JOIN GradeTotals AS G ON G.StudentID = ST.StudentID;
END;
GO

CREATE TRIGGER dbo.trg_Enrollments_MaintainTuition
ON dbo.Enrollments
WITH EXECUTE AS OWNER
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF TRIGGER_NESTLEVEL(OBJECT_ID(N'dbo.trg_Enrollments_MaintainTuition')) > 1
        RETURN;

    IF EXISTS
    (
        SELECT 1
        FROM deleted AS D
        LEFT JOIN inserted AS I ON I.EnrollmentID = D.EnrollmentID
        WHERE I.EnrollmentID IS NULL AND D.Status <> N'Dropped'
    )
        THROW 50012, 'Drop an active enrollment before deleting it; completed/failed history must be retained.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS I
        INNER JOIN deleted AS D ON D.EnrollmentID = I.EnrollmentID
        WHERE I.StudentID <> D.StudentID
           OR I.SectionID <> D.SectionID
           OR I.TuitionCharged <> D.TuitionCharged
           OR (D.Status IN (N'Completed', N'Failed') AND I.Status NOT IN (N'Completed', N'Failed'))
           OR (D.Status = N'Dropped' AND I.Status NOT IN (N'Dropped', N'Enrolled'))
    )
        THROW 50013, 'Enrollment ownership, section, tuition snapshot and terminal status cannot be rewritten.', 1;

    UPDATE E
    SET TuitionCharged = C.TuitionFee
    FROM dbo.Enrollments AS E
    INNER JOIN inserted AS I ON I.EnrollmentID = E.EnrollmentID
    LEFT JOIN deleted AS D ON D.EnrollmentID = I.EnrollmentID
    INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
    INNER JOIN dbo.Courses AS C ON C.CourseID = S.CourseID
    WHERE (D.EnrollmentID IS NULL AND I.Status <> N'Dropped')
       OR (D.Status = N'Dropped' AND I.Status = N'Enrolled');

    WITH Changes AS
    (
        SELECT I.StudentID, E.TuitionCharged AS Amount
        FROM inserted AS I
        LEFT JOIN deleted AS D ON D.EnrollmentID = I.EnrollmentID
        INNER JOIN dbo.Enrollments AS E ON E.EnrollmentID = I.EnrollmentID
        WHERE (D.EnrollmentID IS NULL AND I.Status <> N'Dropped')
           OR (D.Status = N'Dropped' AND I.Status = N'Enrolled')
        UNION ALL
        SELECT D.StudentID, -D.TuitionCharged AS Amount
        FROM deleted AS D
        INNER JOIN inserted AS I ON I.EnrollmentID = D.EnrollmentID
        WHERE D.Status = N'Enrolled' AND I.Status = N'Dropped'
    ),
    Totals AS
    (
        SELECT StudentID, SUM(Amount) AS Amount
        FROM Changes
        GROUP BY StudentID
    )
    UPDATE ST
    SET Balance = CASE WHEN ST.Balance - ST.CreditBalance + T.Amount >= 0
                       THEN ST.Balance - ST.CreditBalance + T.Amount
                       ELSE 0.00 END,
        CreditBalance = CASE WHEN ST.Balance - ST.CreditBalance + T.Amount < 0
                             THEN -(ST.Balance - ST.CreditBalance + T.Amount)
                             ELSE 0.00 END
    FROM dbo.Students AS ST
    INNER JOIN Totals AS T ON T.StudentID = ST.StudentID;
END;
GO

CREATE TRIGGER dbo.trg_Sections_ProtectCourseHistory
ON dbo.Sections
WITH EXECUTE AS OWNER
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS I
        INNER JOIN deleted AS D ON D.SectionID = I.SectionID
        WHERE I.CourseID <> D.CourseID
          AND EXISTS (SELECT 1 FROM dbo.Enrollments AS E WHERE E.SectionID = I.SectionID)
    )
        THROW 50014, 'A section with enrollment history cannot be assigned to another course.', 1;

    IF EXISTS
    (
        SELECT 1
        FROM inserted AS I
        INNER JOIN dbo.Enrollments AS E1
            ON E1.SectionID = I.SectionID AND E1.Status = N'Enrolled'
        INNER JOIN dbo.Enrollments AS E2
            ON E2.StudentID = E1.StudentID
           AND E2.EnrollmentID <> E1.EnrollmentID
           AND E2.Status = N'Enrolled'
        INNER JOIN dbo.Sections AS S2 ON S2.SectionID = E2.SectionID
        WHERE S2.Semester = I.Semester
          AND S2.TimeSlot = I.TimeSlot
    )
        THROW 50016, 'Schedule change denied: An enrolled student has a timetable conflict in the target semester and time slot.', 1;
END;
GO

CREATE TRIGGER dbo.trg_Courses_RecalculateGPA
ON dbo.Courses
WITH EXECUTE AS OWNER
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT UPDATE(Credits)
        RETURN;

    WITH AffectedStudents AS
    (
        SELECT DISTINCT E.StudentID
        FROM dbo.Enrollments AS E
        INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
        INNER JOIN inserted AS I ON I.CourseID = S.CourseID
        INNER JOIN deleted AS D ON D.CourseID = I.CourseID
        WHERE I.Credits <> D.Credits
    ),
    GradeTotals AS
    (
        SELECT E.StudentID,
               SUM(E.Grade * C.Credits) / NULLIF(SUM(C.Credits), 0) AS GPA
        FROM dbo.Enrollments AS E
        INNER JOIN AffectedStudents AS A ON A.StudentID = E.StudentID
        INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
        INNER JOIN dbo.Courses AS C ON C.CourseID = S.CourseID
        WHERE E.Grade IS NOT NULL
          AND E.Status IN (N'Completed', N'Failed')
        GROUP BY E.StudentID
    )
    UPDATE ST
    SET CumulativeGPA = CAST(COALESCE(G.GPA, 0.00) AS DECIMAL(3,2))
    FROM dbo.Students AS ST
    INNER JOIN AffectedStudents AS A ON A.StudentID = ST.StudentID
    LEFT JOIN GradeTotals AS G ON G.StudentID = ST.StudentID;
END;
GO

CREATE PROCEDURE dbo.usp_EnrollStudentInSection
    @StudentID INT,
    @SectionID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF USER_NAME() <> N'dbo' AND ISNULL(IS_MEMBER(N'AdminRole'), 0) <> 1
           AND USER_NAME() <> CONCAT(N'Student_', @StudentID)
            THROW 50011, 'Access denied: You may only manage your own student account.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Students WHERE StudentID = @StudentID)
            THROW 50005, 'Student not found.', 1;

        IF NOT EXISTS (SELECT 1 FROM dbo.Sections WHERE SectionID = @SectionID)
            THROW 50006, 'Classroom section not found.', 1;

        DECLARE @ExistingStatus NVARCHAR(20);
        SELECT @ExistingStatus = Status
        FROM dbo.Enrollments
        WHERE StudentID = @StudentID AND SectionID = @SectionID;

        IF @ExistingStatus IN (N'Enrolled', N'Completed')
            THROW 50008, 'Student is already enrolled in or has completed this section.', 1;

        IF @ExistingStatus = N'Dropped'
            UPDATE dbo.Enrollments
            SET Status = N'Enrolled', Grade = NULL, EnrolledAt = SYSDATETIME()
            WHERE StudentID = @StudentID AND SectionID = @SectionID;
        ELSE IF @ExistingStatus IS NULL
            INSERT INTO dbo.Enrollments (StudentID, SectionID, Status)
            VALUES (@StudentID, @SectionID, N'Enrolled');
        ELSE
            THROW 50010, 'A failed enrollment already exists for this section; choose another section.', 1;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.usp_DropStudentSection
    @StudentID INT,
    @SectionID INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF USER_NAME() <> N'dbo' AND ISNULL(IS_MEMBER(N'AdminRole'), 0) <> 1
           AND USER_NAME() <> CONCAT(N'Student_', @StudentID)
            THROW 50011, 'Access denied: You may only manage your own student account.', 1;

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Enrollments
            WHERE StudentID = @StudentID
              AND SectionID = @SectionID
              AND Status = N'Enrolled'
        )
            THROW 50003, 'Active enrollment not found.', 1;

        UPDATE dbo.Enrollments
        SET Status = N'Dropped'
        WHERE StudentID = @StudentID AND SectionID = @SectionID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.usp_ProcessTuitionPayment
    @StudentID INT,
    @Amount DECIMAL(10,2),
    @PaymentMethod NVARCHAR(50),
    @TransactionReference NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF USER_NAME() <> N'dbo' AND ISNULL(IS_MEMBER(N'AdminRole'), 0) <> 1
           AND USER_NAME() <> CONCAT(N'Student_', @StudentID)
            THROW 50011, 'Access denied: You may only manage your own student account.', 1;

        IF @Amount IS NULL OR @Amount <= 0.00
            THROW 50007, 'Payment amount must be greater than zero.', 1;

        DECLARE @Balance DECIMAL(10,2);
        SELECT @Balance = Balance
        FROM dbo.Students
        WHERE StudentID = @StudentID;

        IF @Balance IS NULL
            THROW 50005, 'Student not found.', 1;
        IF @Amount > @Balance
            THROW 50004, 'Payment amount exceeds current outstanding student balance.', 1;

        INSERT INTO dbo.Payments (StudentID, Amount, PaymentMethod, TransactionReference)
        VALUES (@StudentID, @Amount, @PaymentMethod, @TransactionReference);

        UPDATE dbo.Students
        SET Balance = Balance - @Amount
        WHERE StudentID = @StudentID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE PROCEDURE dbo.usp_RecordStudentGrade
    @StudentID INT,
    @SectionID INT,
    @Grade DECIMAL(3,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        IF @Grade IS NULL OR @Grade < 0.00 OR @Grade > 4.00
            THROW 50018, 'Grade must be between 0.00 and 4.00.', 1;

        DECLARE @InstructorID INT;
        SELECT @InstructorID = InstructorID
        FROM dbo.Sections
        WHERE SectionID = @SectionID;

        IF @InstructorID IS NULL
            THROW 50006, 'Classroom section not found.', 1;

        IF USER_NAME() <> N'dbo' AND ISNULL(IS_MEMBER(N'AdminRole'), 0) <> 1
           AND NOT (ISNULL(IS_MEMBER(N'InstructorRole'), 0) = 1
                    AND USER_NAME() = CONCAT(N'Instructor_', @InstructorID))
            THROW 50017, 'Access denied: Only the assigned section instructor or an administrator may record grades.', 1;

        DECLARE @CurrentStatus NVARCHAR(20);
        SELECT @CurrentStatus = Status
        FROM dbo.Enrollments
        WHERE StudentID = @StudentID AND SectionID = @SectionID;

        IF @CurrentStatus IS NULL OR @CurrentStatus = N'Dropped'
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Students WHERE StudentID = @StudentID)
               AND (USER_NAME() = N'dbo' OR ISNULL(IS_MEMBER(N'AdminRole'), 0) = 1)
                THROW 50005, 'Student not found.', 1;
            THROW 50003, 'Active enrollment not found.', 1;
        END;

        UPDATE dbo.Enrollments
        SET Grade = @Grade,
            Status = CASE WHEN @Grade >= 1.00 THEN N'Completed' ELSE N'Failed' END
        WHERE StudentID = @StudentID AND SectionID = @SectionID;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;

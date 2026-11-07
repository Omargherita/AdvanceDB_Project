CREATE ROLE AdminRole;
CREATE ROLE InstructorRole;
CREATE ROLE StudentRole;

GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Departments TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Instructors TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Students TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Courses TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.CoursePrerequisites TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Sections TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Enrollments TO AdminRole;
GRANT SELECT, INSERT, UPDATE, DELETE ON dbo.Payments TO AdminRole;
GRANT SELECT ON dbo.vw_StudentTranscript TO AdminRole;
GRANT SELECT ON dbo.vw_DepartmentEnrollmentStats TO AdminRole;
GRANT SELECT ON dbo.vw_InstructorTeachingLoad TO AdminRole;
GRANT SELECT ON dbo.vw_UnpaidTuitionAccounts TO AdminRole;
GRANT EXECUTE ON dbo.usp_EnrollStudentInSection TO AdminRole;
GRANT EXECUTE ON dbo.usp_DropStudentSection TO AdminRole;
GRANT EXECUTE ON dbo.usp_ProcessTuitionPayment TO AdminRole;
GRANT EXECUTE ON dbo.usp_RecordStudentGrade TO AdminRole;

GRANT SELECT ON dbo.Departments TO InstructorRole;
GRANT SELECT ON dbo.Instructors TO InstructorRole;
GRANT SELECT ON dbo.Courses TO InstructorRole;
GRANT SELECT ON dbo.CoursePrerequisites TO InstructorRole;
GRANT SELECT ON dbo.Sections TO InstructorRole;
GRANT SELECT (StudentID, FullName, Email, DeptID, CumulativeGPA, EnrollmentDate) ON dbo.Students TO InstructorRole;
DENY SELECT (Balance, CreditBalance) ON dbo.Students TO InstructorRole;
GRANT SELECT ON dbo.Enrollments TO InstructorRole;
GRANT SELECT ON dbo.vw_InstructorTeachingLoad TO InstructorRole;
GRANT SELECT ON dbo.vw_StudentTranscript TO InstructorRole;
GRANT UPDATE (Grade, Status) ON dbo.Enrollments TO InstructorRole;
GRANT EXECUTE ON dbo.usp_RecordStudentGrade TO InstructorRole;
DENY SELECT, INSERT, UPDATE, DELETE ON dbo.Payments TO InstructorRole;
DENY SELECT ON dbo.vw_UnpaidTuitionAccounts TO InstructorRole;

GRANT SELECT ON dbo.Departments TO StudentRole;
GRANT SELECT ON dbo.Instructors TO StudentRole;
GRANT SELECT ON dbo.Students TO StudentRole;
GRANT SELECT ON dbo.Enrollments TO StudentRole;
GRANT SELECT ON dbo.Payments TO StudentRole;
GRANT SELECT ON dbo.Courses TO StudentRole;
GRANT SELECT ON dbo.CoursePrerequisites TO StudentRole;
GRANT SELECT ON dbo.Sections TO StudentRole;
GRANT SELECT ON dbo.vw_StudentTranscript TO StudentRole;
GRANT EXECUTE ON dbo.usp_EnrollStudentInSection TO StudentRole;
GRANT EXECUTE ON dbo.usp_DropStudentSection TO StudentRole;
GRANT EXECUTE ON dbo.usp_ProcessTuitionPayment TO StudentRole;
DENY EXECUTE ON dbo.usp_RecordStudentGrade TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Departments TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Instructors TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Students TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Courses TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.CoursePrerequisites TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Sections TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Enrollments TO StudentRole;
DENY INSERT, UPDATE, DELETE ON dbo.Payments TO StudentRole;
GO

CREATE FUNCTION dbo.fn_EnrollmentAccess(@StudentID INT, @SectionID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    WHERE USER_NAME() = N'dbo' OR IS_MEMBER(N'AdminRole') = 1
       OR (IS_MEMBER(N'StudentRole') = 1 AND USER_NAME() = CONCAT(N'Student_', @StudentID))
       OR (IS_MEMBER(N'InstructorRole') = 1 AND EXISTS
           (SELECT 1 FROM dbo.Sections AS S
            WHERE S.SectionID = @SectionID
              AND USER_NAME() = CONCAT(N'Instructor_', S.InstructorID)));
GO

CREATE FUNCTION dbo.fn_EnrollmentUpdateAccess(@StudentID INT, @SectionID INT, @Status NVARCHAR(20))
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    WHERE USER_NAME() = N'dbo' OR IS_MEMBER(N'AdminRole') = 1
       OR (IS_MEMBER(N'StudentRole') = 1
           AND USER_NAME() = CONCAT(N'Student_', @StudentID)
           AND @Status IN (N'Enrolled', N'Dropped'))
       OR (IS_MEMBER(N'InstructorRole') = 1
           AND @Status IN (N'Completed', N'Failed')
           AND EXISTS
           (SELECT 1 FROM dbo.Sections AS S
            WHERE S.SectionID = @SectionID
              AND USER_NAME() = CONCAT(N'Instructor_', S.InstructorID)));
GO

CREATE FUNCTION dbo.fn_StudentAccountAccess(@StudentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    WHERE USER_NAME() = N'dbo' OR IS_MEMBER(N'AdminRole') = 1
       OR (IS_MEMBER(N'StudentRole') = 1 AND USER_NAME() = CONCAT(N'Student_', @StudentID));
GO

CREATE FUNCTION dbo.fn_StudentProfileAccess(@StudentID INT)
RETURNS TABLE
WITH SCHEMABINDING
AS
RETURN
    SELECT 1 AS Allowed
    WHERE USER_NAME() = N'dbo' OR IS_MEMBER(N'AdminRole') = 1
       OR (IS_MEMBER(N'StudentRole') = 1 AND USER_NAME() = CONCAT(N'Student_', @StudentID))
       OR (IS_MEMBER(N'InstructorRole') = 1 AND EXISTS
           (SELECT 1 FROM dbo.Enrollments AS E
            INNER JOIN dbo.Sections AS S ON S.SectionID = E.SectionID
            WHERE E.StudentID = @StudentID
              AND USER_NAME() = CONCAT(N'Instructor_', S.InstructorID)));
GO

CREATE SECURITY POLICY dbo.OSMS_RecordAccess
    ADD FILTER PREDICATE dbo.fn_EnrollmentAccess(StudentID, SectionID) ON dbo.Enrollments,
    ADD BLOCK PREDICATE dbo.fn_EnrollmentAccess(StudentID, SectionID) ON dbo.Enrollments AFTER INSERT,
    ADD BLOCK PREDICATE dbo.fn_EnrollmentAccess(StudentID, SectionID) ON dbo.Enrollments BEFORE UPDATE,
    ADD BLOCK PREDICATE dbo.fn_EnrollmentUpdateAccess(StudentID, SectionID, Status) ON dbo.Enrollments AFTER UPDATE,
    ADD FILTER PREDICATE dbo.fn_StudentProfileAccess(StudentID) ON dbo.Students,
    ADD FILTER PREDICATE dbo.fn_StudentAccountAccess(StudentID) ON dbo.Payments,
    ADD BLOCK PREDICATE dbo.fn_StudentAccountAccess(StudentID) ON dbo.Payments AFTER INSERT
WITH (STATE = ON, SCHEMABINDING = ON);

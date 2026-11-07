
CREATE TABLE dbo.Departments
(
    DeptID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Departments PRIMARY KEY,
    DeptName NVARCHAR(100) NOT NULL
        CONSTRAINT UQ_Departments_Name UNIQUE
);

CREATE TABLE dbo.Instructors
(
    InstructorID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Instructors PRIMARY KEY,
    FullName NVARCHAR(150) NOT NULL,
    Email NVARCHAR(100) NOT NULL
        CONSTRAINT UQ_Instructors_Email UNIQUE,
    DeptID INT NOT NULL
        CONSTRAINT FK_Instructors_Departments
        REFERENCES dbo.Departments(DeptID)
);

CREATE TABLE dbo.Students
(
    StudentID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Students PRIMARY KEY,
    FullName NVARCHAR(150) NOT NULL,
    Email NVARCHAR(100) NOT NULL
        CONSTRAINT UQ_Students_Email UNIQUE,
    DeptID INT NOT NULL
        CONSTRAINT FK_Students_Departments
        REFERENCES dbo.Departments(DeptID),
    CumulativeGPA DECIMAL(3,2) NOT NULL
        CONSTRAINT DF_Students_CumulativeGPA DEFAULT (0.00)
        CONSTRAINT CHK_Students_GPA
        CHECK (CumulativeGPA BETWEEN 0.00 AND 4.00),
    Balance DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Students_Balance DEFAULT (0.00)
        CONSTRAINT CHK_Students_Balance CHECK (Balance >= 0.00),
    CreditBalance DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Students_CreditBalance DEFAULT (0.00)
        CONSTRAINT CHK_Students_CreditBalance CHECK (CreditBalance >= 0.00),
    CONSTRAINT CHK_Students_NetBalance CHECK (Balance = 0.00 OR CreditBalance = 0.00),
    EnrollmentDate DATE NOT NULL
        CONSTRAINT DF_Students_EnrollmentDate
        DEFAULT (CAST(GETDATE() AS DATE))
);

CREATE TABLE dbo.Courses
(
    CourseID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Courses PRIMARY KEY,
    CourseCode NVARCHAR(20) NOT NULL
        CONSTRAINT UQ_Courses_Code UNIQUE,
    CourseName NVARCHAR(150) NOT NULL,
    Credits INT NOT NULL
        CONSTRAINT CHK_Courses_Credits CHECK (Credits BETWEEN 1 AND 6),
    TuitionFee DECIMAL(10,2) NOT NULL
        CONSTRAINT CHK_Courses_Fee CHECK (TuitionFee >= 0.00),
    DeptID INT NOT NULL
        CONSTRAINT FK_Courses_Departments
        REFERENCES dbo.Departments(DeptID)
);

CREATE TABLE dbo.CoursePrerequisites
(
    PrereqID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_CoursePrerequisites PRIMARY KEY,
    CourseID INT NOT NULL
        CONSTRAINT FK_Prereq_Course REFERENCES dbo.Courses(CourseID),
    PrereqCourseID INT NOT NULL
        CONSTRAINT FK_Prereq_Required REFERENCES dbo.Courses(CourseID),
    CONSTRAINT UQ_CoursePrerequisites_Pair
        UNIQUE (CourseID, PrereqCourseID),
    CONSTRAINT CHK_Prereq_Self CHECK (CourseID <> PrereqCourseID)
);

CREATE TABLE dbo.Sections
(
    SectionID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Sections PRIMARY KEY,
    CourseID INT NOT NULL
        CONSTRAINT FK_Sections_Courses REFERENCES dbo.Courses(CourseID),
    InstructorID INT NOT NULL
        CONSTRAINT FK_Sections_Instructors
        REFERENCES dbo.Instructors(InstructorID),
    Semester NVARCHAR(20) NOT NULL,
    RoomNumber NVARCHAR(30) NOT NULL,
    TimeSlot NVARCHAR(50) NOT NULL,
    MaxCapacity INT NOT NULL
        CONSTRAINT CHK_Sections_MaxCapacity CHECK (MaxCapacity > 0),
    EnrolledCount INT NOT NULL
        CONSTRAINT DF_Sections_EnrolledCount DEFAULT (0),
    CONSTRAINT CHK_Sections_TimeSlot CHECK (TimeSlot IN
        (N'MW 08:30-10:00', N'MW 10:00-11:30', N'MW 11:30-13:00', N'MW 13:00-14:30',
         N'TTh 08:30-10:00', N'TTh 10:00-11:30', N'TTh 11:30-13:00', N'TTh 13:00-14:30')),
    CONSTRAINT UQ_Sections_RoomSchedule UNIQUE (Semester, RoomNumber, TimeSlot),
    CONSTRAINT UQ_Sections_InstructorSchedule UNIQUE (Semester, InstructorID, TimeSlot),
    CONSTRAINT CHK_Sections_CapacityBounds
        CHECK (EnrolledCount >= 0 AND EnrolledCount <= MaxCapacity)
);

CREATE TABLE dbo.Enrollments
(
    EnrollmentID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Enrollments PRIMARY KEY,
    StudentID INT NOT NULL
        CONSTRAINT FK_Enrollments_Students
        REFERENCES dbo.Students(StudentID),
    SectionID INT NOT NULL
        CONSTRAINT FK_Enrollments_Sections
        REFERENCES dbo.Sections(SectionID),
    TuitionCharged DECIMAL(10,2) NOT NULL
        CONSTRAINT DF_Enrollments_TuitionCharged DEFAULT (0.00)
        CONSTRAINT CHK_Enrollments_TuitionCharged CHECK (TuitionCharged >= 0.00),
    Grade DECIMAL(3,2) NULL
        CONSTRAINT CHK_Enrollments_Grade
        CHECK (Grade BETWEEN 0.00 AND 4.00),
    Status NVARCHAR(20) NOT NULL
        CONSTRAINT DF_Enrollments_Status DEFAULT (N'Enrolled')
        CONSTRAINT CHK_Enrollments_Status
        CHECK (Status IN (N'Enrolled', N'Completed', N'Dropped', N'Failed')),
    CONSTRAINT CHK_Enrollments_GradeStatus
        CHECK ((Status IN (N'Enrolled', N'Dropped') AND Grade IS NULL)
            OR (Status = N'Completed' AND Grade IS NOT NULL AND Grade >= 1.00)
            OR (Status = N'Failed' AND Grade IS NOT NULL AND Grade < 1.00)),
    EnrolledAt DATETIME2 NOT NULL
        CONSTRAINT DF_Enrollments_EnrolledAt DEFAULT (SYSDATETIME()),
    CONSTRAINT UQ_Student_Section UNIQUE (StudentID, SectionID)
);

CREATE TABLE dbo.Payments
(
    PaymentID INT IDENTITY(1,1) NOT NULL
        CONSTRAINT PK_Payments PRIMARY KEY,
    StudentID INT NOT NULL
        CONSTRAINT FK_Payments_Students
        REFERENCES dbo.Students(StudentID),
    Amount DECIMAL(10,2) NOT NULL
        CONSTRAINT CHK_Payments_Amount CHECK (Amount > 0.00),
    PaymentDate DATETIME2 NOT NULL
        CONSTRAINT DF_Payments_PaymentDate DEFAULT (SYSDATETIME()),
    PaymentMethod NVARCHAR(50) NOT NULL
        CONSTRAINT CHK_Payments_Method
        CHECK (PaymentMethod IN (N'Cash', N'Credit Card', N'Bank Transfer')),
    TransactionReference NVARCHAR(100) NULL
);

CREATE INDEX IX_Enrollments_Section_Status
    ON dbo.Enrollments (SectionID, Status) INCLUDE (StudentID, Grade);
CREATE INDEX IX_Sections_Course
    ON dbo.Sections (CourseID) INCLUDE (InstructorID);

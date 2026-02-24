-- SQL Server schema for optional proxy and enterprise telemetry
-- Compatible with SQL Server 2019+

CREATE TABLE dbo.KoboUsers (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    ServerUrl NVARCHAR(512) NOT NULL,
    KoboUsername NVARCHAR(256) NOT NULL,
    DisplayName NVARCHAR(256) NULL,
    LastLoginAt DATETIME2 NULL,
    IsActive BIT NOT NULL DEFAULT 1,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_KoboUsers_Server_Username UNIQUE (ServerUrl, KoboUsername)
);

CREATE TABLE dbo.Forms (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    ServerUrl NVARCHAR(512) NOT NULL,
    KoboFormId NVARCHAR(128) NOT NULL,
    ProjectId NVARCHAR(128) NULL,
    Title NVARCHAR(500) NOT NULL,
    ActiveVersionId UNIQUEIDENTIFIER NULL,
    IsArchived BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Forms_Server_Form UNIQUE (ServerUrl, KoboFormId)
);

CREATE TABLE dbo.FormVersions (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    FormId UNIQUEIDENTIFIER NOT NULL,
    VersionLabel NVARCHAR(128) NULL,
    VersionHash NVARCHAR(128) NOT NULL,
    XFormXml NVARCHAR(MAX) NOT NULL,
    NamespaceUri NVARCHAR(512) NULL,
    DefaultLanguage NVARCHAR(16) NULL,
    IsLatest BIT NOT NULL DEFAULT 0,
    PublishedAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_FormVersions_Forms FOREIGN KEY (FormId) REFERENCES dbo.Forms(Id),
    CONSTRAINT UQ_FormVersions_Form_VersionHash UNIQUE (FormId, VersionHash)
);

ALTER TABLE dbo.Forms
ADD CONSTRAINT FK_Forms_ActiveVersion FOREIGN KEY (ActiveVersionId) REFERENCES dbo.FormVersions(Id);

CREATE TABLE dbo.Submissions (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    FormVersionId UNIQUEIDENTIFIER NOT NULL,
    UserId UNIQUEIDENTIFIER NULL,
    LocalInstanceId NVARCHAR(128) NOT NULL,
    SubmissionUuid NVARCHAR(128) NOT NULL,
    DeviceId NVARCHAR(128) NULL,
    Status NVARCHAR(32) NOT NULL,
    DraftJson NVARCHAR(MAX) NULL,
    InstanceXml NVARCHAR(MAX) NULL,
    XmlFileName NVARCHAR(255) NULL,
    KoboReceipt NVARCHAR(MAX) NULL,
    RetryCount INT NOT NULL DEFAULT 0,
    NextRetryAt DATETIME2 NULL,
    LastErrorCode NVARCHAR(64) NULL,
    LastErrorMessage NVARCHAR(2000) NULL,
    FinalizedAt DATETIME2 NULL,
    SyncedAt DATETIME2 NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Submissions_FormVersions FOREIGN KEY (FormVersionId) REFERENCES dbo.FormVersions(Id),
    CONSTRAINT FK_Submissions_Users FOREIGN KEY (UserId) REFERENCES dbo.KoboUsers(Id),
    CONSTRAINT CK_Submissions_Status CHECK (Status IN ('Draft','Completed','PendingUpload','Synced','Failed')),
    CONSTRAINT UQ_Submissions_LocalInstance UNIQUE (FormVersionId, LocalInstanceId)
);

CREATE TABLE dbo.SubmissionMedia (
    Id UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID() PRIMARY KEY,
    SubmissionId UNIQUEIDENTIFIER NOT NULL,
    XmlQuestionPath NVARCHAR(500) NOT NULL,
    FileName NVARCHAR(255) NOT NULL,
    MimeType NVARCHAR(128) NOT NULL,
    LocalPath NVARCHAR(1000) NOT NULL,
    ByteLength BIGINT NOT NULL,
    Sha256 NVARCHAR(128) NOT NULL,
    SortOrder INT NOT NULL DEFAULT 0,
    Uploaded BIT NOT NULL DEFAULT 0,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_SubmissionMedia_Submissions FOREIGN KEY (SubmissionId) REFERENCES dbo.Submissions(Id),
    CONSTRAINT UQ_SubmissionMedia_Submission_FileName UNIQUE (SubmissionId, FileName)
);

CREATE TABLE dbo.SyncLogs (
    Id BIGINT IDENTITY(1,1) PRIMARY KEY,
    SubmissionId UNIQUEIDENTIFIER NULL,
    CorrelationId NVARCHAR(64) NOT NULL,
    EventType NVARCHAR(64) NOT NULL,
    Severity NVARCHAR(16) NOT NULL,
    Message NVARCHAR(2000) NOT NULL,
    HttpStatusCode INT NULL,
    ErrorCode NVARCHAR(64) NULL,
    PayloadHash NVARCHAR(128) NULL,
    CreatedAt DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_SyncLogs_Submissions FOREIGN KEY (SubmissionId) REFERENCES dbo.Submissions(Id)
);

CREATE INDEX IX_FormVersions_Form_IsLatest ON dbo.FormVersions(FormId, IsLatest);
CREATE INDEX IX_Submissions_Status_NextRetry ON dbo.Submissions(Status, NextRetryAt);
CREATE INDEX IX_SubmissionMedia_Submission_Sort ON dbo.SubmissionMedia(SubmissionId, SortOrder);
CREATE INDEX IX_SyncLogs_Correlation ON dbo.SyncLogs(CorrelationId, CreatedAt);


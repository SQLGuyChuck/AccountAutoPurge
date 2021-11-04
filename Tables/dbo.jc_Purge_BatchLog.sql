SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_BatchLog]') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.jc_Purge_BatchLog (
	BatchID INT NOT NULL IDENTITY(1,1),
	InitiatedbyCorpDomainUsername VARCHAR(100) NOT NULL,--My corp domain username, e.g. chuck.lathrope
	TicketAuditLogMessage VARCHAR (100) NOT NULL,
	DateAdded DATETIME2	(4) NULL CONSTRAINT [DF_jc_Purge_BatchLog_DateAdded]  DEFAULT (sysdatetime()),
	DateStartKeyAdd DATETIME2(4),
	DateEndKeyAdd DATETIME2(4),
	TotalRowsAdded INT,
	DateStartTableDelete DATETIME2(4),
	DateCompleted DATETIME2(4),
	TotalRowsDeleted INT,
	BatchTypeId SMALLINT
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_BatchLog]') AND name = N'PK_jc_Purge_BatchLog_BatchID')
BEGIN
ALTER TABLE [dbo].[jc_Purge_BatchLog]
ADD CONSTRAINT [PK_jc_Purge_BatchLog_BatchID] PRIMARY KEY CLUSTERED 
(
	BatchID ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
END
GO

IF NOT EXISTS (select * from information_schema.columns where table_name = 'jc_Purge_BatchLog' and column_name = 'BatchTypeId')
BEGIN
	ALTER TABLE [dbo].[jc_Purge_BatchLog] ADD [BatchTypeId] smallint
END
GO
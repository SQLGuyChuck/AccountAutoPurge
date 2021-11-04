SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_TableLog]') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.jc_Purge_TableLog (
	BatchID INT NOT NULL,
	TableID SMALLINT NOT NULL,
	DateStartKeyAdd DATETIME2(4),
	DateEndKeyAdd DATETIME2(4),
	RowsAdded INT,
	DateStartTableDelete DATETIME2(4),
	DateCompleted DATETIME2(4),
	RowsDeleted INT
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_TableLog]') AND name = N'PK_jc_Purge_TableLog_BatchID_TableID')
BEGIN
ALTER TABLE [dbo].[jc_Purge_TableLog]
ADD CONSTRAINT [PK_jc_Purge_TableLog_BatchID_TableID] PRIMARY KEY CLUSTERED 
(
	BatchID ASC,
	TableID ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY]
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_ListofTablesToPurgeAccountsFrom]') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.jc_Purge_ListofTablesToPurgeAccountsFrom(
	[TableID] [smallint] IDENTITY(1,1) NOT NULL,
	[TableName] [varchar](100) NOT NULL,
	[KeyName] [varchar](100) NOT NULL,
	[KeyIsNumber] [bit] NOT NULL
) ON [PRIMARY]
END
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_ListofTablesToPurgeAccountsFrom]') AND name = N'PK_jc_Purge_ListofTablesToPurgeAccountsFrom_TableID' and type = 2)
BEGIN
ALTER TABLE [dbo].[jc_Purge_ListofTablesToPurgeAccountsFrom]
DROP CONSTRAINT [PK_jc_Purge_ListofTablesToPurgeAccountsFrom_TableID]
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_ListofTablesToPurgeAccountsFrom]') AND name = N'PK_jc_Purge_ListofTablesToPurgeAccountsFrom_TableID' and type = 1)
BEGIN
ALTER TABLE [dbo].[jc_Purge_ListofTablesToPurgeAccountsFrom]
ADD CONSTRAINT [PK_jc_Purge_ListofTablesToPurgeAccountsFrom_TableID] PRIMARY KEY CLUSTERED 
(
	[TableID] ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY]
END
GO

IF NOT EXISTS (select * from information_schema.columns where table_name = 'jc_Purge_ListofTablesToPurgeAccountsFrom' and column_name = 'TableDeleteOrder')
BEGIN
	ALTER TABLE dbo.jc_Purge_ListofTablesToPurgeAccountsFrom ADD TableDeleteOrder smallint
END
GO
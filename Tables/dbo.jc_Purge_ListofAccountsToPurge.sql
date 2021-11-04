
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_ListofAccountsToPurge]') AND type in (N'U'))
BEGIN
CREATE TABLE [dbo].[jc_Purge_ListofAccountsToPurge](
	[BatchID] [int] NOT NULL,
	[AccountID] [int] NOT NULL,
	[UserName] [varchar](64) NULL,
	[DotnetUserID] [uniqueidentifier] NULL,
	[CSUserID] [int] NULL,
	[SectionID] [int] NULL
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_ListofAccountsToPurge]') AND name = N'PK_jc_Purge_ListofAccountsToPurge_AccountID')
BEGIN
ALTER TABLE [dbo].[jc_Purge_ListofAccountsToPurge]
ADD CONSTRAINT [PK_jc_Purge_ListofAccountsToPurge_AccountID] PRIMARY KEY NONCLUSTERED 
(
	[AccountID] ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_ListofAccountsToPurge]') AND name = N'cix_jc_Purge_ListofAccountsToPurge_BatchID_AccountID')
BEGIN
CREATE CLUSTERED INDEX [cix_jc_Purge_ListofAccountsToPurge_BatchID_AccountID] ON [dbo].[jc_Purge_ListofAccountsToPurge]
(
	[BatchID] ASC,
	[AccountID] ASC
) ON [PRIMARY]
END
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_KeyValuesToDelete]') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.jc_Purge_KeyValuesToDelete(
	[PurgeKeyID] [bigint] IDENTITY(1,1) NOT NULL,
	[BatchID] INT NOT NULL,
	[TableID] SMALLINT NOT NULL,
	[Varcharvalue] [varchar](100) NULL,
	[IntValue] [int] NULL
	) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_KeyValuesToDelete]') AND name = N'PK_jc_Purge_KeyValuesToDelete_PurgeKeyID')
BEGIN
ALTER TABLE [dbo].[jc_Purge_KeyValuesToDelete]
ADD CONSTRAINT [PK_jc_Purge_KeyValuesToDelete_PurgeKeyID] PRIMARY KEY CLUSTERED 
(
[PurgeKeyID] ASC
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY]
END
GO
	

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_KeyValuesToDelete]') AND name = N'uix_jc_Purge_KeyValuesToDelete_TableID_Varcharvalue_IntValue')
BEGIN
CREATE UNIQUE NONCLUSTERED INDEX [uix_jc_Purge_KeyValuesToDelete_TableID_Varcharvalue_IntValue] ON [dbo].[jc_Purge_KeyValuesToDelete]
(
	[TableID] ASC,
	[Varcharvalue] ASC,
	[IntValue] ASC
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_KeyValuesToDelete]') AND name = N'ix_jc_Purge_KeyValuesToDelete_BatchID_TableID')
BEGIN
CREATE INDEX ix_jc_Purge_KeyValuesToDelete_BatchID_TableID ON jc_Purge_KeyValuesToDelete (BatchID, TableID) ON [PRIMARY]
END
GO

IF EXISTS (
SELECT * FROM sys.objects o 
inner join sys.all_columns c on o.object_id = c.object_id 
WHERE o.object_id = OBJECT_ID(N'[dbo].[jc_Purge_KeyValuesToDelete]') AND o.type in (N'U')
and  c.name = 'Varcharvalue' and c.max_length = '50'
)
BEGIN
	alter table jc_Purge_KeyValuesToDelete
	alter column VarcharValue varchar(100)
END

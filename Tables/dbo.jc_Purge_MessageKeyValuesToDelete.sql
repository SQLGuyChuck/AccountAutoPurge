SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_MessageKeyValuesToDelete]') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.jc_Purge_MessageKeyValuesToDelete(
	BatchID INT NOT NULL,
	MessageID UNIQUEIDENTIFIER NOT NULL
) ON [PRIMARY]
END
GO

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_MessageKeyValuesToDelete]') AND name = N'PK_jc_Purge_MessageKeyValuesToDelete_BatchID_MessageID' and type = 2)
BEGIN
ALTER TABLE [dbo].[jc_Purge_MessageKeyValuesToDelete]
DROP CONSTRAINT [PK_jc_Purge_MessageKeyValuesToDelete_BatchID_MessageID]
END

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_MessageKeyValuesToDelete]') AND name = N'PK_jc_Purge_MessageKeyValuesToDelete_BatchID_MessageID' and type = 1)
BEGIN
ALTER TABLE [dbo].[jc_Purge_MessageKeyValuesToDelete]
ADD CONSTRAINT [PK_jc_Purge_MessageKeyValuesToDelete_BatchID_MessageID] PRIMARY KEY CLUSTERED 
(
	BatchID,
	MessageID
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY]
END
GO
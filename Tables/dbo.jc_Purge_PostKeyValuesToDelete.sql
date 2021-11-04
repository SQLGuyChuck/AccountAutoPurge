SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_PostKeyValuesToDelete]') AND type in (N'U'))
BEGIN
CREATE TABLE dbo.jc_Purge_PostKeyValuesToDelete(
	BatchID INT NOT NULL,
	PostID INT NOT NULL
)ON [PRIMARY]
END

IF EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_PostKeyValuesToDelete]') AND name = N'PK_jc_Purge_PostKeyValuesToDelete_BatchID_PostID' and type = 2)
BEGIN
ALTER TABLE [dbo].[jc_Purge_PostKeyValuesToDelete]
DROP CONSTRAINT [PK_jc_Purge_PostKeyValuesToDelete_BatchID_PostID]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[dbo].[jc_Purge_PostKeyValuesToDelete]') AND name = N'PK_jc_Purge_PostKeyValuesToDelete_BatchID_PostID' and type = 1)
BEGIN
ALTER TABLE [dbo].[jc_Purge_PostKeyValuesToDelete]
ADD CONSTRAINT [PK_jc_Purge_PostKeyValuesToDelete_BatchID_PostID] PRIMARY KEY CLUSTERED 
(
	BatchID,
	PostID
)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON
) ON [PRIMARY]
END
GO
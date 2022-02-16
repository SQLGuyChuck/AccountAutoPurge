SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_AddPurgeKeys
	@BatchID INT
AS
BEGIN
-- ======================================================================================
-- Author:		Chuck Lathrope
-- Create date: 4/27/2016
-- Description:	Find PK values for data in the tables you would like to purge from.
--				Update logging tables with timing and rowcounts.
--				Tables are in order of deletion to prevent FK errors, so up to you to get right.
--
-- Note: If a table is deleted from the database, and this stored procedure was deleting data from it, just remove the
-- table name from this stored procedure. Do not remove the table name from jc_Purge_ListofTablesToPurgeAccountsFrom
-- since all deleted batches have used the TableID and we need to still reference the TableID values correctly.
--
-- Change History:
-- Change Date	Change By	Short change description
-- 2/16/2022	Chuck L		Updated to be generic for first time use.
-- ======================================================================================
SET NOCOUNT, XACT_ABORT ON;

--Update batch start info
UPDATE jc_Purge_BatchLog SET DateStartKeyAdd = SYSDATETIME()
WHERE BatchID = @BatchID

--Step 1 (per table): Update Table batch info with start time
UPDATE dbo.jc_Purge_TableLog SET DateStartKeyAdd = SYSDATETIME()
WHERE BatchID = @BatchID
AND TableID = 1

--Step 2 (per table): Insert PK to be deleted
INSERT INTO dbo.jc_Purge_KeyValuesToDelete (BatchID, TableID, Varcharvalue, IntValue)
SELECT @BatchID, 1,NULL,tab.ID
FROM AccountDomains tab
JOIN jc_Purge_ListofAccountsToPurge info ON info.AccountID = ua.AccountID AND info.BatchID = @BatchID
LEFT JOIN jc_Purge_KeyValuesToDelete del ON del.IntValue = tab.Id AND del.TableID = 1 AND del.BatchID = @BatchID
WHERE
	del.IntValue IS NULL;

--Step 3 (per table): Update Table batch info with end time and row count
UPDATE dbo.jc_Purge_TableLog 
SET DateEndKeyAdd = SYSDATETIME(), RowsAdded = ISNULL(RowsAdded,0)+@@ROWCOUNT
WHERE BatchID = @BatchID
AND TableID = 1

--Rinse and repeat the 3 steps for remainder of tables. 



--Update batch End info
UPDATE jc_Purge_BatchLog SET DateEndKeyAdd = SYSDATETIME(), TotalRowsAdded = CNT
FROM (SELECT COUNT(*) AS CNT FROM jc_Purge_KeyValuesToDelete WHERE BatchID = @BatchID) t
WHERE BatchID = @BatchID

END
GO

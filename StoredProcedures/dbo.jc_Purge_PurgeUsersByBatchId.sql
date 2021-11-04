SET QUOTED_IDENTIFIER ON
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_PurgeUsersByBatchId
	@BatchId INT,
	@BatchSize SMALLINT = 200,
	@OverrideTimeConstraint BIT = 0,	--If 1, then run purge now
	@PurgeStatus TINYINT OUTPUT --Only used for time of day exit
WITH EXECUTE AS OWNER
AS 
BEGIN
-- ======================================================================================
-- Author:		Chuck Lathrope
-- Create date: 4/27/2016
-- Description:	Purges batches from jc_Purge_ListofTablesToPurgeAccountsFrom. Exits when
--				it reaches 4AM or Monday at 12:01 AM.
--
-- Change History:
-- Change Date	Change By	Short change description
-- 4/27/2016	ChuckL		Initial Creation
-- 06/01/2018	MelanieL	Adding functionality for automated deletion
-- 10/01/2018	MelanieL	Remove DBOPS.dbo.prc_Error; doesn't work in Azure SQL
-- 10/09/2018	MelanieL	Add @OverrideTimeConstraint to allow for running ad-hoc by test automation and DBA
-- 10/17/2018	MelanieL	Initializing @CanRun, remove print of @RowsAlreadyDeleted as it is not needed for automation
-- 11/5/2018	MelanieL	Added LOCAL to CURSOR declaration
-- 2/17/2019	ChuckL		Error handling and logic improvements	
-- 8/3/2020		ChuckL		Modify error handling to remove generic response
-- 8/5/2020		ChuckL		Add execute as owner to prevent website from failing on asp_membership reads
-- 9/2/2020		ChuckL		Error condition improvements
-- 11/16/2020	MichaelC	Bug Fix
-- ======================================================================================
SET NOCOUNT, XACT_ABORT ON;

DECLARE 
	@TableID SMALLINT = 1
	,@Rowcount INT = -1
	,@RowsAdded INT = 0
	,@RowsDeleted INT = 0
	,@RowsAlreadyDeleted INT
	,@TableRowsAlreadyDeleted SMALLINT
	,@DeleteCommand NVARCHAR(2000)
	,@UpdateCommand NVARCHAR(2000)
	,@ParmDefinition NVARCHAR(500) = N'@RowsAlreadyDeleted INT, @RowsDeleted INT OUTPUT'
	,@now TIME(0)
	,@DayofWeek TINYINT

--Initialize time boundary
SET DATEFIRST 1	--1 is Monday
SET @DayofWeek = DATEPART(WEEKDAY, GETDATE())
SET @now = CAST(GETDATE() AS TIME)

IF @OverrideTimeConstraint = 0
BEGIN
	IF (
		(@DayofWeek IN (1,2,3,4,5) AND (@now >= '16:00' OR @now < '04:00'))	--4pm-4am
		OR
		(@DayofWeek IN (6,7) AND @now < '21:00') --Saturday and Sunday before 9 pm
	)
		SET @PurgeStatus = 0
	ELSE
	BEGIN
		SET @PurgeStatus = 1;

		PRINT 'Outside time bounds, but Batch was created and will be purged at night because override was not set.'
		SELECT @BatchId as BatchID  
  
		RETURN 
	END
END
ELSE 
	SET @PurgeStatus = 0


--If we stopped in middle of a delete, grab rowcount.
SELECT TOP 1 @RowsAlreadyDeleted = tl.RowsDeleted, @TableRowsAlreadyDeleted = tl.TableID
FROM
	jc_Purge_TableLog tl
	JOIN dbo.jc_Purge_ListofTablesToPurgeAccountsFrom t on t.tableid = tl.tableid
WHERE
	BatchID = @BatchID
	AND DateCompleted IS NULL
	AND RowsDeleted > 0
ORDER BY t.TableDeleteOrder

--Table cursor contents
DECLARE TableCursor CURSOR LOCAL FORWARD_ONLY READ_ONLY FOR
SELECT f.TableID, 'DECLARE @iRowcount INT
WHILE @iRowcount > 0 OR @iRowcount IS NULL
BEGIN
DELETE TOP (' + CAST(@BatchSize AS VARCHAR(10)) + ') t 
FROM ' + tablename + ' t WITH (ROWLOCK) join jc_Purge_KeyValuesToDelete d on ' 
	+ CASE WHEN f.KeyIsNumber = 1 THEN 'd.IntValue' ELSE 'd.Varcharvalue' end + ' = t.' + keyname + ' 
WHERE d.TableID = ' + CAST(f.TableID AS VARCHAR(5))+ ' AND d.BatchID = ' + CAST(@BatchID AS VARCHAR(10)) + ' 
SELECT @irowcount = @@ROWCOUNT, @RowsDeleted = @RowsDeleted + @@ROWCOUNT

IF @irowcount > 0
BEGIN
	UPDATE jc_Purge_TableLog
	SET RowsDeleted = @RowsDeleted + ISNULL(@RowsAlreadyDeleted,0)
	WHERE BatchID = ' + CAST(@BatchID AS VARCHAR(10)) + '
	AND TableID = ' + CAST(f.TableID AS VARCHAR(5)) + '

	RAISERROR (''%i Rows deleted from table ' + tablename + ''',0,1,@RowsDeleted) WITH NOWAIT
	WAITFOR DELAY ''00:00:02.0''
END

IF @RowsDeleted % ' + CAST(@BatchSize * CASE WHEN @BatchSize < 2000 THEN 500 ELSE 20 END AS VARCHAR(20)) + ' = 0
BEGIN
	RAISERROR (''Purging rows deleted from jc_Purge_KeyValuesToDelete.'',0,1) WITH NOWAIT
	DELETE d 
	FROM jc_Purge_KeyValuesToDelete d 
	WHERE NOT EXISTS (SELECT 1 FROM ' + tablename + ' t WHERE ' + CASE WHEN f.KeyIsNumber = 1 THEN 'd.IntValue' ELSE 'd.Varcharvalue' end + ' = t.' + keyname + '  )
	AND d.TableID = ' + CAST(f.TableID AS VARCHAR(5))+ ' AND d.BatchID = ' + CAST(@BatchID AS VARCHAR(10)) + '
END
END'
	,t.RowsAdded
FROM dbo.jc_Purge_ListofTablesToPurgeAccountsFrom f
JOIN dbo.jc_Purge_TableLog t ON t.TableID = f.TableID AND t.BatchID = @BatchID
WHERE t.RowsAdded > 0 
AND t.DateCompleted IS NULL
ORDER BY f.TableDeleteOrder

UPDATE dbo.jc_Purge_BatchLog
SET DateStartTableDelete = SYSDATETIME()
WHERE BatchID = @BatchID

OPEN TableCursor
FETCH NEXT FROM TableCursor INTO @TableID, @DeleteCommand, @RowsAdded

WHILE @@FETCH_STATUS = 0
BEGIN
	BEGIN TRY

		UPDATE jc_Purge_TableLog
		SET DateStartTableDelete = SYSDATETIME()
		WHERE BatchID = @BatchID
		AND TableID = @TableID

		EXECUTE sp_executesql
			@DeleteCommand,
			@ParmDefinition,
			@RowsAlreadyDeleted,
			@RowsDeleted= @RowsDeleted OUTPUT;

		IF @TableRowsAlreadyDeleted = @TableID
			SET @RowsDeleted = @RowsDeleted + ISNULL(@RowsAlreadyDeleted,0)

		--Update Logging table
		UPDATE jc_Purge_TableLog
		SET DateCompleted = SYSDATETIME(), RowsDeleted = @RowsDeleted
		WHERE BatchID = @BatchID
		AND TableID = @TableID

		IF @RowsAdded > @RowsDeleted
		BEGIN
			--Remove rows from key table as this could be endless loop
			DELETE FROM jc_Purge_KeyValuesToDelete
			WHERE TableID = @TableID AND BatchID = @BatchID
			
			--This requires someone or automated process to run again. Most likely some other process is deleting data at same time.
			RAISERROR ('For some reason, we didn''t delete as many rows as expected and will leave data in purge table. Command: %s. Delete count: %i, Rows expected: %i.',16,1,@DeleteCommand, @RowsDeleted, @RowsAdded) WITH NOWAIT
		END
		ELSE
		BEGIN
			DELETE FROM jc_Purge_KeyValuesToDelete
			WHERE TableID = @TableID AND BatchID = @BatchID
		END

		IF @RowsDeleted % 100000 = 0
			CHECKPOINT --In case automatic checkpoint hasn't been run.

	END TRY
	BEGIN CATCH
		PRINT @DeleteCommand;
		THROW;
	END CATCH

	SET @now = CAST(GETDATE() AS TIME)

	IF @OverrideTimeConstraint = 0
	BEGIN
		IF (
			(@DayofWeek IN (1,2,3,4,5) AND (@now >= '16:00' OR @now < '04:00'))	--4pm-4am
			OR
			(@DayofWeek IN (6,7) AND @now < '21:00') --Saturday and Sunday before 9 pm
		)
			SET @PurgeStatus = 0
		ELSE
		BEGIN
			SET @PurgeStatus = 1
			GOTO ExitProc
		END
	END

	SELECT @RowsDeleted = 0, @RowsAlreadyDeleted = 0
	FETCH NEXT FROM TableCursor INTO @TableID, @DeleteCommand, @RowsAdded

END--End Table cursor

--Update batch info
IF @PurgeStatus = 0
BEGIN
	UPDATE dbo.jc_Purge_BatchLog
	SET DateCompleted = t.DateCompleted, TotalRowsDeleted = t.TotalRowsDeleted
	FROM (
		SELECT SUM(l.RowsDeleted) AS TotalRowsDeleted, MAX(l.DateCompleted) AS DateCompleted
		FROM dbo.jc_Purge_TableLog l
		WHERE BatchID = @BatchID) t
	WHERE jc_Purge_BatchLog.BatchID = @BatchID
END

ExitProc:

CLOSE TableCursor
DEALLOCATE TableCursor

END
GO
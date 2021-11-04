SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_AutomatedPurgeProcessWrapper
	  @OverrideTimeConstraint BIT = 0	--If 1, then run purge now
	, @BatchId INT = NULL --Pass in if just a specific batch you want to run.
	, @BatchTypeId TINYINT = 1	--1=Ad-hoc Account, 2=Archive, 3=Manual, 4=Employer
	, @BatchSize INT = 200
AS
BEGIN
-- ======================================================================================
-- Author:		Melanie Labuguen
-- Create date: 6/01/2018
-- Description:	Wrapper that will manage the account purge process.
--				Called nightly by sql agent job to purge all non-completed batches by BatchTypeId
--
-- Change History:
-- Change Date	Change By	Short change description
-- 6/01/2018	Melanie L	Initial Creation
-- 10/09/2018	MelanieL	Add @OverrideTimeConstraint to allow for running ad-hoc by test automation and DBA
-- 2/11/2019	ChuckL		Major overhaul and repurposing
-- 2/21/2019	ChuckL		Add BatchSize parameter
-- 4/27/2019	ChuckL		Allow for null batchlog rowsadded
-- 9/2/2020		ChuckL		Error condition improvements
-- ======================================================================================
	SET NOCOUNT, XACT_ABORT ON;

	DECLARE @PurgeStatus TINYINT
		  , @NumAccountsToPurge INT
		  , @Count INT
		  , @Date DATETIME2(4)

	DECLARE BatchList CURSOR FORWARD_ONLY READ_ONLY FOR

	--Find all batches ready to go for passed in BatchTypeId, override BatchId to specific batch if passed in @BatchId
	SELECT bl.BatchId, ISNULL(SUM(tl.RowsDeleted),0) RowsDeleted, bl.DateAdded
	FROM dbo.jc_Purge_BatchLog bl
	JOIN dbo.jc_Purge_TableLog tl ON tl.BatchID = bl.BatchID
	WHERE bl.DateCompleted IS NULL
	AND BatchTypeId = @BatchTypeId
	AND bl.BatchID = ISNULL(@BatchID, bl.BatchID)--Limit to passed in BatchId if passed in.
	GROUP BY bl.BatchId, bl.DateAdded
	ORDER BY SUM(tl.RowsDeleted) DESC, bl.DateAdded

	OPEN BatchList
	FETCH NEXT FROM BatchList INTO @BatchId, @Count, @Date
	WHILE (@@FETCH_STATUS = 0)
	BEGIN
		BEGIN TRY
			IF EXISTS (SELECT 1 FROM jc_Purge_BatchLog
					   WHERE BatchID = @BatchID
					   AND DateEndKeyAdd IS NULL)
				EXEC jc_Purge_AddPurgeKeys @BatchId = @BatchId

			EXEC jc_Purge_PurgeUsersByBatchId @BatchId = @BatchId, @BatchSize = @BatchSize, @OverrideTimeConstraint = @OverrideTimeConstraint, @PurgeStatus = @PurgeStatus OUTPUT

			IF @PurgeStatus <> 0 --Time of day limitor was reached
			BEGIN
				PRINT 'Time limit reached'
				GOTO TimeLimitReached
			END

			--Perform cleanup
			EXEC jc_Purge_PostPurgeCleanupByBatchId @BatchId = @BatchId

			IF @BatchTypeId = 4
				EXEC jc_Purge_PostPurgeEmployerCleanupByBatchId @BatchId = @BatchId

		END TRY
		BEGIN CATCH
			RAISERROR('Error caught in purging accounts in automation.',16,1);
			THROW;
		END CATCH

		FETCH NEXT FROM BatchList INTO @BatchId, @Count, @Date
	END

	TimeLimitReached:
	CLOSE BatchList
    DEALLOCATE BatchList

END
GO
SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_PostPurgeEmployerCleanupByBatchId
	@BatchID INT
AS
BEGIN
-- ======================================================================================
-- Author:		Chuck Lathrope
-- Create date: 4/27/2016
-- Description:	Performs cleanup tasks after a purge batch is completed for parent entity of Employer.
--				Used only if a parent exists to an account.
--
-- Change History:
-- Change Date	Change By	Short change description
-- 4/27/2016	ChuckL		Initial Creation
-- 7/20/2020	ChuckL		Add ability to purge orphaned employer user account
-- ======================================================================================
	SET NOCOUNT, XACT_ABORT ON;

	--Check to see if any records have not been deleted.
	IF EXISTS (
		SELECT 1
		FROM dbo.jc_Purge_TableLog tl
		WHERE tl.BatchID = @BatchID
		AND tl.RowsAdded > 0
		AND tl.DateCompleted IS NULL)
	BEGIN
  		RAISERROR('Rows found in batch that haven''t been marked as deleted.', 16, 1, 'jc_Purge_PostPurgeEmployerCleanupByBatchId')

		RETURN 1
	END

	--Get EmployerId stored in BatchLog message.
	DECLARE @EmployerName VARCHAR(64)
			,@EmployerID INT

	SELECT @EmployerID = CAST(SUBSTRING(TicketAuditLogMessage,CHARINDEX('=',TicketAuditLogMessage)+1,CHARINDEX(':',TicketAuditLogMessage)-CHARINDEX('=',TicketAuditLogMessage)-1) AS INT)
	FROM jc_Purge_BatchLog
	WHERE BatchID = @BatchID

	IF @EmployerID > 0 --Bypass against orphaned employer user accounttype=4 processes that call this proc.
	BEGIN

		--Example table based on parent entity:
		DELETE FROM EmployerDetails WHERE EmployerId = @EmployerId


		--Finally delete the employer parent entity:
		DELETE FROM jc_Employer WHERE EmployerId = @EmployerId;
		
	END

	--Now clean up the purge accounts table as all is done
	IF (SELECT COUNT(*) FROM jc_Purge_ListofAccountsToPurge WHERE BatchID <> @BatchID) = 0
		TRUNCATE TABLE dbo.jc_Purge_ListofAccountsToPurge
	ELSE
	BEGIN 
		DELETE FROM jc_Purge_ListofAccountsToPurge WHERE BatchID = @BatchID
	END

END
GO

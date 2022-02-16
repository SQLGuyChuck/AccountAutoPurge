SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_PurgeEmployer
(
	@EmployerName varchar(64),
	@AuditLogInitiatorUserName varchar(100) = NULL,
	@ImmediatePurge bit = 0,--Start the purge now if 1, else batch up to next batch purge run.
	@BatchSize INT = 200,
	@BatchID INT OUTPUT
)
AS
BEGIN
-- ======================================================================================
-- Author:		Chuck Lathrope
-- Create date: ?
-- Description:	Add all users and former users to purge table for nightly delete process including employer account.
--
-- Change History:
-- Change Date	Change By	Short change description
-- 12/27/2018	ChuckL		Major change in purpose to just add users to purge table and nightly process adds keys and deletes data.
--							Added @BatchID output for wrapper process in sql job.
-- 2/21/2019	ChuckL		Bug fix for multiple sections. Add BatchSize parameter
-- 7/20/2020	ChuckL		Add ability to purge orphaned employer user account
-- ======================================================================================
	SET NOCOUNT ON;

	DECLARE @TicketAuditLogMessage VARCHAR(100)
		  , @PurgeStatus TINYINT
		  , @NumAccountsToPurge INT
		  , @EmployerUsername VARCHAR(64)
		  , @EmployerId INT

	-- If initiator username not supplied, use the DB username.
	IF (@AuditLogInitiatorUserName IS NULL) 
		SET @AuditLogInitiatorUserName = SUSER_SNAME();

	-- Validate @EmployerName parameter.
    SELECT @EmployerId=EmployerId FROM Employer WHERE EmployerName = @EmployerName;
	
	--Check if we found account.
    IF (@EmployerId IS NULL AND @EmployerUsername IS NULL)
	BEGIN 
		DECLARE @invalidEmployerError NVARCHAR(1000) = 'Unable to purge employer. Invalid employer name : '+ ISNULL(@EmployerName, '');
		RAISERROR (@invalidEmployerError, 16, 1);
		RETURN 
	END 

	--Make sure employer account is not already in the accounts to purge table
	IF EXISTS ( SELECT 1
				FROM Employer e 
					JOIN jc_Purge_ListofAccountsToPurge p ON p.UserName = e.EmployerName
				WHERE
					e.EmployerId = @EmployerId
					OR p.UserName = @EmployerUsername --Domain specific, may not need if parent entity doesn't have a username in the accounts table.
				)
	BEGIN
		PRINT 'Employer account is already in purge table.'
		RETURN --Nothing to do
	END


	BEGIN TRY
	
		--Create a specifically formatted message for wrapper proc to grab the EmployerId from the info stored.	
		SET @TicketAuditLogMessage = 'EmployerId=' + CAST(@EmployerId AS VARCHAR(10)) + ': EmployerName is ''' + @EmployerName + ''' - called from Purge Employer Proc'

		--Get a new BatchId
		EXEC dbo.jc_Purge_AddBatch @InitiatedBy = @AuditLogInitiatorUserName, 
			@TicketAuditLogMessage = @TicketAuditLogMessage, 
			@BatchTypeId = 4, -- Employer delete
			@BatchID = @BatchID OUTPUT
			
		PRINT @BatchID

		--Add current and former accounts to the purge table for employer
		INSERT jc_Purge_ListofAccountsToPurge
			(BatchID, AccountID, UserName,  DotnetUserID)
		SELECT
			@BatchID,
			a.AccountID,
			a.UserName,
			a.DotnetUserID
		FROM
			Accounts a
			LEFT JOIN jc_Purge_ListofAccountsToPurge p ON p.AccountID = a.AccountID
		WHERE
			(a.EmployerId = @EmployerId 
				OR (a.Username = @EmployerUsername and @EmployerUsername IS NOT NULL)
				)
			AND p.AccountID IS NULL --Don't add user's already in purge table (from some other batch most likely).

		-- Insert to the audit log optional step
		--IF @EmployerUsername IS NULL --Don't log orphaned user as should already be logged and would have null below.
		--BEGIN
		--	INSERT INTO jc_AuditLog (ActionInitiator, ActionType, ActionScope, Username, Timestamp, AuditData, IPAddress, ParameterName, ParameterValue)
		--	SELECT @AuditLogInitiatorUserName, 38, 0, @EmployerName, GETDATE(), null, null, 'jc_Purge_PurgeEmployer called', 
		--		'EmployerName: ' + @EmployerName 
		--		+ ', Email: ' + (SELECT Email FROM cs_Users WHERE Username = @EmployerName)
		--		+ ', Employer XML: ' + (SELECT * FROM Employer WHERE EmployerName = @EmployerName FOR XML AUTO);
		--END

		IF @ImmediatePurge = 1
		BEGIN
			EXEC jc_Purge_AddPurgeKeys @BatchId = @BatchId

			EXEC jc_Purge_PurgeUsersByBatchId @BatchId = @BatchId, @BatchSize = @BatchSize, @OverrideTimeConstraint = 1, @PurgeStatus = @PurgeStatus OUTPUT

			EXEC jc_Purge_PostPurgeCleanupByBatchId @BatchId = @BatchId

			EXEC jc_Purge_PostPurgeEmployerCleanupByBatchId @BatchId = @BatchId

		END

	END TRY
	BEGIN CATCH
		THROW;
	END CATCH
END



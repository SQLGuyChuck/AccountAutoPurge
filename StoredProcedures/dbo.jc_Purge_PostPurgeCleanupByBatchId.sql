SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_PostPurgeCleanupByBatchId
	@BatchID INT
AS
BEGIN
-- ======================================================================================
-- Author:		Chuck Lathrope
-- Create date: 4/27/2016
-- Description:	Performs cleanup tasks after a purge batch is completed.
--
-- Change History:
-- Change Date	Change By	Short change description
-- 4/27/2016	ChuckL		Initial Creation
-- 1/1/2019		ChuckL		Add batchid to auditlog and check for completion.
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
  		RAISERROR('Rows found in batch that haven''t been marked as deleted.', 16, 1, 'jc_Purge_PostPurgeCleanupByBatchId')

		RETURN 1
	END

	--Use this proc if there are post processes to clean up tables like Community Server posts updates to be anonymous users now that user is purged for example:
	--Clean up threads to have anonymous user replace the user's id.
	DECLARE @anonymousUserName varchar(64) = 'anonymous'
		, @anonymousUserID int;
	SELECT @anonymousUserID = UserID FROM cs_Users WHERE UserName = @anonymousUserName;

	UPDATE tab SET MostRecentPostAuthorID = @anonymousUserID, MostRecentPostAuthor = @anonymousUserName
	FROM cs_Sections tab INNER JOIN jc_Purge_ListofAccountsToPurge info ON tab.MostRecentPostAuthorID = info.CSUserID AND info.CSUserID > 0 AND info.BatchID = @BatchID;
				
	UPDATE tab SET UserID = @anonymousUserID
	FROM cs_Threads tab INNER JOIN jc_Purge_ListofAccountsToPurge info ON info.CSUserID = tab.UserID AND info.CSUserID > 0 AND info.BatchID = @BatchID;
				
	UPDATE tab SET MostRecentPostAuthorID = @anonymousUserID, MostRecentPostAuthor = @anonymousUserName
	FROM cs_Threads tab INNER JOIN jc_Purge_ListofAccountsToPurge info ON tab.MostRecentPostAuthorID = info.CSUserID AND info.CSUserID > 0 AND info.BatchID = @BatchID;

	UPDATE tab SET MostRecentPostID = 0, MostRecentPostAuthorID = 0, MostRecentPostAuthor = NULL, PostCount = 0, CommentCount = 0, TrackbackCount = 0
	FROM cs_weblog_Weblogs tab INNER JOIN jc_Purge_ListofAccountsToPurge info ON tab.MostRecentPostAuthorID = info.CSUserID AND info.CSUserID > 0 AND info.BatchID = @BatchID;			

	UPDATE tab SET username = @anonymousUserName
	FROM dbo.jc_Feedback tab JOIN jc_Purge_ListofAccountsToPurge info ON tab.Username = info.username AND info.BatchID = @BatchID;


	--Now remove the account from the jc_Purge_ListofAccountsToPurge as we are all done!

	--For logging to auditlog:
	--DECLARE @deleted TABLE (
	--	batchid INT
	--   ,Username VARCHAR(64)
	--   ,AccountID INT
	--   ,CSUserID INT
	--);

	DELETE FROM jc_Purge_ListofAccountsToPurge 
	--OUTPUT DELETED.Batchid, DELETED.Username, DELETED.AccountID --Add remove columns as needed here for logging to an auditlog
	--INTO @deleted 
	WHERE BatchID = @BatchID

	-- If you have a standard auditlog, you can insert info on who got deleted.  ActionType 6 = Purge Account.
	--INSERT INTO jc_AuditLog (ActionInitiator, ActionType, ActionScope, Username, Timestamp, AuditData, IPAddress, ParameterName, ParameterValue)
	--SELECT
	--	l.InitiatedbyCorpDomainUsername, 6, 0, Username, GETDATE(), null, null, 'Purged user.', 
	--	'BatchID: ' + CAST(p.Batchid AS VARCHAR(20)) + ' Ticket: ' + l.TicketAuditLogMessage + '. Username: ' + ISNULL(UserName, '') + ' AccountID: ' + CAST(AccountID AS VARCHAR(20)) 
	--FROM
	--	@deleted p
	--	INNER JOIN dbo.jc_Purge_BatchLog l on p.BatchID = l.BatchID	

END
GO

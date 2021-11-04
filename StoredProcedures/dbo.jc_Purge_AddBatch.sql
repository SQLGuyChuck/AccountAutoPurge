SET QUOTED_IDENTIFIER ON --Quoted elements must use ' and not "
GO
CREATE OR ALTER PROCEDURE dbo.jc_Purge_AddBatch
	@InitiatedBy VARCHAR(100),
	@TicketAuditLogMessage VARCHAR(100),
	@BatchTypeId SMALLINT,
	@BatchID int OUTPUT
AS
BEGIN
-- ======================================================================================
-- Author:		Chuck Lathrope
-- Create date: 4/27/2016
-- Description:	Create new BatchID for processing of accounts to purge from database.
--
-- Example:
-- DECLARE @batchid INT
-- exec jc_Purge_AddBatch @InitiatedBy = 'Chuck.Lathrope', @TicketAuditLogMessage = 'TEAM-1', @batchid = @batchid OUTPUT
-- SELECT @batchid

-- Change History:
-- Change Date	Change By	Short change description
-- 4/27/2016	ChuckL		Initial Creation
-- 9/21/2018	Melanie L	Added BatchTypeId to handle consumer purge and archiving
-- 12/30/18		Chuck L		Exclude tables we don't have anymore.
-- ======================================================================================
	SET NOCOUNT, XACT_ABORT ON;
	
	--Create a batch for inserts
	INSERT INTO dbo.jc_Purge_BatchLog
			(InitiatedbyCorpDomainUsername,
			 TicketAuditLogMessage,
			 BatchTypeId
			 )
	SELECT	@InitiatedBy, @TicketAuditLogMessage, @BatchTypeId
	
	SET @BatchID = SCOPE_IDENTITY()

	--Add tables to batch
	INSERT INTO dbo.jc_Purge_TableLog
			(BatchID,
			 TableID
			 )
	SELECT	@BatchID,
			 TableID
	FROM dbo.jc_Purge_ListofTablesToPurgeAccountsFrom lt
	JOIN sys.tables t ON lt.TableName = t.name AND t.schema_id = 1 AND lt.TableDeleteOrder > 0

END

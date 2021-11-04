# AccountAutoPurge
This code repo provides a process to automate the purge of data in SQL Server tables based on a user identifier that slowly deletes all of a user's data for cases like GDPR Article 17 right to erasure.

Developed and written by Chuck Lathrope (SQLGuyChuck) with help from Melanie Labuguen and Michael Capobianco. Please do help contribute via forking code and creating PR against it so I will see or request features. I use Gmail for email if you want to reach me at my alias.

## Why
This process was developed out of necessity of GDPR Article 17 for a data subjects rights to erasure. This can be accomplished in a couple of ways:
1. By anonymizing the data by which a data scientist with all the data accessible in the world could not reverse engineer the data to re-identify a human.
2. Just delete the data. This code utilizes this process. The advantage of this is that you can use it for slowly deleting data in an OLTP system for really any purpose.

## Architecture
This code was written for SQL Server. Nothing sophisticated, so probably could be used on SQL Server 2005+. Concepts could easily be ported to other SQL engines.

## Design Premise
The idea behind this is that deleting data can cause a production outage in an OLTP system that is in Full recovery mode (you care about log recovery). For example (simplified), if you start to delete a few hundred rows of the data in a table, the SQL engine will need to initiate locks on the data to prevent others from modifying it. This starts blocking other users of the table from making changes to it, and even can block readers if the database is not using RCSI or user is not using NOLOCK hints (bad idea for code, ok typically for ad-hoc use). So, you start these huge blocking chains until your delete is completed. So, the goal is to do small deletes with little delays between them to allow the system to "breathe" in the most optimum manner possible. Blocking will happen, but if it lasts 100's of milliseconds or a second, you are probably okay. Lower batch size if it becomes a problem.

## Architecture
The design is based on control tables to log what you want to delete in batches. It will track everything for you and allows you to stop it at any point and recover where it left off. It also allows for different types of batches that would be domain specific. For example, I need to purge one users account would be one batch type and another would be all accounts for a customer that terminated. These batch types are used such that you can have different SQL jobs kick them off and have more finer grained control on process and business logic.

### Control tables
#### Long term tables
You document all the tables to purge from and their primary keys in jc_Purge_ListofTablesToPurgeAccountsFrom and specify the order of table delete to eliminate foreign key constraint issues. If you have multiple environments, keep the table ID values the same manually as the Ids are often hard coded in stored procedures to help the optimizer not have parameterization issues with table ids.
The system stores table purge metrics in jc_Purge_TableLog. This table is used to auto-recover where it left off and track stats.
The system stored batches in jc_Purge_BatchLog. This could be a batch of one user of batch type "user". Or a batch of all the users for a customer with batch type "customer". You give it the batch type labels, but they become integers in the code.

#### Temporary tables:
You store all the accounts you want to delete temporarily in jc_Purge_ListofAccountsToPurge.
The system stores primary keys temporarily in jc_Purge_KeyValuesToDelete

### Simple process flow for Account Deletion:
The proc jc_Purge_AutomatedPurgeProcessWrapper automates all of this:
1.	We create a batch of some batch type and get back a BatchId that is an Identity value from the jc_Purge_BatchLog table. Proc jc_Purge_AddBatch does this.
2.	We add users to purge to that BatchId. Proc jc_Purge_PopulateListofAccountsToPurge does this.
3.	We add the primary keys of the tables to the purge keys table for all those users in step 2. The list of tables is stored in a control table with the primary key column name documented as used in procs. Proc jc_Purge_AddPurgeKeys does this.
4.	Purge all the keys from the table in small batches, pause 2 seconds in between batches to allow for replication to not be overwhelmed and allow system to "breathe". Proc     jc_Purge_PurgeUsersByBatchId does this and does the following things:
  1. Log updates to tablelog for rows deleted on periodic basis while delete operation is running and check if still with acceptable time window to delete, exit if not.
  2. Update statistics and purge from temporary control tables to help optimize the deletes on a row count cadence.
6.	Finalize the process with misc cleanup and mark batch completed. Proc jc_Purge_PostPurgeCleanupByBatchId does this.

### Stored procedure details
This section contains some specific details for some of the stored procedure in the purge process.

jc_Purge_AddPurgeKeys: When there is a new table from which data needs to be purged, this stored procedure needs to be updated to include it. In addition, the new table information must be added to the table named jc_Purge_ListofTablesToPurgeAccountsFrom. Set table order = 0 when deprecating a table from the process and don't delete it to keep historical purge values in place for reporting purposes.

jc_Purge_AutomatedPurgeProcessWrapper: Wrapper to do the work after purge accounts and keys are populated. There is an input parameter named @OverrideTimeConstraint that, when set to 1, is used to allow purging out of the defined don’t process timeframes. The timeframes are defined in jc_Purge_PurgeUsersByBatchId (see below). It will process all batches of specified BatchTypeID passed in.

jc_Purge_PurgeUsersByBatchId: Purges users by BatchID

To be uploaded:
jc_Purge_PopulateListofAccountsToPurge: This stored procedure populates the table that controls the list of accounts jc_Purge_ListofAccountsToPurge. In addition, this stored procedure populates the table jc_Purge_ListofAccountsToPurge with any username passed to it.

jc_Purge_PostPurgeCleanupByBatchId: An example of a manual post user purge process that cleans up posts created by any account that is purged as this process doesn't handle a table with two UserIds being used in a table.

jc_Purge_PostPurgeEmployerCleanupByBatchId: An example of a post processing of BatchTypeID = 4 for customer purges. It would be used to purge customer metadata.

### BatchTypeIDs: There are currently four BatchTypeIDs that are used to manage different kinds of purges.
BatchTypeID 1 = User account purges. Can be 1 to bigint size.
BatchTypeID 2 = Archive purge. To be used for table archive process. A separate process that I may document here, but would use different procs to control it.
BatchTypeID 3 = DBA purge (No automation). Used for extremely large purges performed off-hours (like purging millions of rows from numerous tables). We do not want the nightly process to handle these purges because the purge takes hours over many days and any new accounts to be deleted will not be processed.
BatchTypeID 4 = Full customer purge that allows for customer metadata purge with jc_Purge_PostPurgeEmployerCleanupByBatchId


## Limitations
It currently only allows for one column to identify a user and to use one column to delete the rows in a table. So, if you have a composite key of more that one column, hopefully the user id or a surrogate key is in it and you can still delete with that one key. e.g. if key was UserId + Date the code would do a delete top (100) of table where UserId = x. It would not be able add the date value. That could be a future feature add, I just didn't have the need yet.

If you have a table that uses the primary key in two columns, say for example a commment table that has MessageFrom and MessageTo, instead of having two tables in the table list to delete from which would cause row count checks to break, I created a process for post processing that would just manually take care of the rows missed by which ever column you said in the table list.

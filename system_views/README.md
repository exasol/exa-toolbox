# Table of Contents

<!-- toc -->

- [System views](#system-views)
  * [SCHEMA_SIZES](#schema_sizes)
  * [TABLE_SIZES_TOP_100](#table_sizes_top_100)
  * [AUDITING_LONG_RUNNING_DML_LAST24HOURS](#auditing_long_running_dml_last24hours)
  * [AUDITING_LONG_RUNNING_DQL_LAST24HOURS](#auditing_long_running_dql_last24hours)
  * [PROFILE_OF_RUNNING_QUERIES](#profile_of_running_queries)
  * [GENERAL_SYSTEM_INFO](#general_system_info)
  * [SESSIONS](#sessions)
  * [DB_SIZE_LAST_DAY](#db_size_last_day)
  * [DB_SIZE_DAILY](#db_size_daily)

<!-- tocstop -->

# System views

## SCHEMA_SIZES

The idea behind this view is to give you the exact figures as to the size in GiB each schema within your database consumes. 
From the column `RAW Size in GiB [uncompressed]` you can view the uncompressed RAW volume of each schema. Followed by the compressed size which is currently consumed within the storage of your Exasol database. The `Compression [RAW/MEM]` will show you the compression ratio based on the compressed and RAW figures for each schema.

More information regarding the `EXA_ALL_OBJECT_SIZES` system table can be found by clicking [here.](https://docs.exasol.com/sql_references/metadata/metadata_system_tables.htm#EXA_ALL_OBJECT_SIZES/)

## TABLE_SIZES_TOP_100

This is a similar view to the `SCHEMA_SIZES` view above but on a table level. So you can see how much each table takes up in the storage of the database.

## AUDITING_LONG_RUNNING_DML_LAST24HOURS
This will give you a list of all the data manipulation queries from the last 24 hours. Ordered by the duration. Please be aware you must have administrative privileges in order to query the system table provided from this view. The system table used within this view is the `EXA_DBA_AUDIT_SQL` table. Click [here](https://docs.exasol.com/sql_references/metadata/statistical_system_table.htm#EXA_DBA_AUDIT_SQL) for more info regarding this particular table.

In order to view data you must make sure you have auditing enabled via EXAoperation. Once it has been enabled the database will record all the queries executed.

## AUDITING_LONG_RUNNING_DQL_LAST24HOURS
This is a list of data query language queries within the last 24 hours. You must have the administrator privilege in order to do a `SELECT` on this table or run the view. Auditing must be enabled from EXAoperation, you will not be able to view already executed queries if auditing is disabled. Auditing can be enabled from editing the database from EXAoperation. More information of each specific column within the table can be found by clicking [here.](https://docs.exasol.com/sql_references/metadata/statistical_system_table.htm#EXA_DBA_AUDIT_SQL)

## PROFILE_OF_RUNNING_QUERIES
List of current queries being executed within the database. You must have the administrator privilege in order to view this table. The table will provide details as to the resources which were required (CPU, RAM etc) in order to execute the query. A description of each column from the table `EXA_DBA_PROFILE_RUNNING` can be found by clicking [here.](https://docs.exasol.com/sql_references/metadata/statistical_system_table.htm#EXA_DBA_PROFILE_RUNNING)

## GENERAL_SYSTEM_INFO
Information regarding the Exasol system. Such as the current number of active data nodes with also the overall total database RAM. This view can help you keep track of the of the current version of the database and the replication border without logging into EXAoperation. If you however wish to make any changes, this can be done via EXAoperation.

## SESSIONS
All the sessions from different clients which are currently connected to the Exasol database are listed on this table. The view also gives you an indication as to which session is yours by the `Current Session` column. click [here](https://docs.exasol.com/sql_references/metadata/metadata_system_tables.htm#EXA_DBA_SESSIONS) for more information on the columns of the table `EXA_DBA_SESSIONS`.

## DB_SIZE_LAST_DAY
This will show you the overall current size of the database within the last day. Along with some other useful information such as what is the current recommended database RAM size and the current storage being used. You must have the administrative privilege in order to view this table. More information about the columns can be found by clicking [here.](https://docs.exasol.com/sql_references/metadata/statistical_system_table.htm#EXA_DB_SIZE_LAST_DAY)

## DB_SIZE_DAILY
Within the last 31 days, this view will show you how much the database has changed. Some useful columns include how much the compression ratio has changed, also will give you an indication on the storage so you may therefore decide on if an expansion is needed or not. An indication is given on how much storage is consumed for the indices and statistics. The table which is being referenced from the view is the `EXA_DB_SIZE_DAILY` table, if you wish to have a look at the column descriptions then please click [here.](https://docs.exasol.com/sql_references/metadata/statistical_system_table.htm#EXA_DB_SIZE_DAILY)




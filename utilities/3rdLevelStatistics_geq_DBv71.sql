/*
        The script to export database usage statistics for investigation by support.
        This script applies for Exasol Database versions starting from 7.1.
        
        Originally mentioned in article https://exasol.my.site.com/s/article/Statistics-export-for-support?language=en_US
*/

set autocommit off;

-- The "days" parameter is using EXAplus syntax, which may have to be modified for other clients.
define days = &1;

alter session set NLS_DATE_FORMAT = 'YYYY-MM-DD';
alter session set NLS_FIRST_DAY_OF_WEEK = 7;
alter session set NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH:MI:SS.FF6';
alter session set NLS_NUMERIC_CHARACTERS = '.,';
alter session set NLS_DATE_LANGUAGE = 'ENG';
alter session set QUERY_TIMEOUT = 0;
alter session set SQL_PREPROCESSOR_SCRIPT = '';
alter session set SNAPSHOT_MODE='SYSTEM TABLES';

-- from former 3rdLevelStats_leq_DBv70_Hourly.sql
export (select * from "$EXA_MONITOR_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'monitor_hourly.csv.gz' truncate;
export (select * from EXA_USAGE_HOURLY where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'usage_hourly.csv.gz' truncate;
export (select * from "$EXA_SQL_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'sql_hourly.csv.gz' truncate;
export (select * from "$EXA_PROFILE_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'profile_hourly.csv.gz' truncate;
export (select * from "$EXA_DB_SIZE_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'db_size_hourly.csv.gz' truncate;
export (select * from "$EXA_SYSTEM_EVENTS" where MEASURE_TIME >= (SELECT LEAST(ADD_DAYS(systimestamp, -&days), MAX(MEASURE_TIME)) FROM "$EXA_SYSTEM_EVENTS" WHERE EVENT_TYPE='STARTUP')) into local csv file 'system_events.csv.gz' truncate;
export (select param_value from exa_metadata where param_name = 'databaseProductVersion') into local csv file 'database_version.csv.gz' truncate;

-- from former 3rdLevelStats_leq_DBv70_LastDay.sql
export (select * from "$EXA_MONITOR_DETAILS_LAST_DAY") into local csv file 'monitor_details_last_day.csv.gz' truncate;
export (select * from EXA_USAGE_LAST_DAY) into local csv file 'usage_last_day.csv.gz' truncate;
export (select * from "$EXA_SQL_LAST_DAY") into local csv file 'sql_last_day.csv.gz' truncate;
export (select SESSION_ID,LOGIN_TIME,LOGOUT_TIME,CLIENT,DRIVER,ENCRYPTED,SUCCESS,ERROR_CODE,ERROR_TEXT from EXA_DBA_SESSIONS_LAST_DAY) into local csv file 'all_sessions.csv.gz' truncate;
export (select * from EXA_DBA_TRANSACTION_CONFLICTS where coalesce(STOP_TIME,START_TIME) > add_hours(systimestamp, -24)) into local csv file 'transaction_conflicts.csv.gz' truncate;

-- from former 3rdLevelStats_leq_DBv70_Indices.sql
export (select * from "EXA_VOLUME_USAGE") into local csv file 'volume_usage.csv.gz' truncate;

-- new in 7.1
export (select * from "$EXA_DBRAM_CONTENT_%") into local csv file 'dbram_content.csv.gz' truncate;
export (select * from EXA_PARAMETERS) into local csv file 'parameters.csv.gz' truncate;
export (select * from "$EXA_CLUSTER_NODES") into local csv file 'cluster_nodes.csv.gz' truncate;
export (select * from EXA_STATISTICS_OBJECT_SIZES) into local csv file 'statistics_object_sizes.csv.gz' truncate;
export (select * from "$EXA_STATS_LOGJOB_HISTORY" where MEASURE_TIME > ADD_DAYS(systimestamp, -&days)) into local csv file 'logjob_history.csv.gz' truncate;

select 'exported system tables and statistics of last &days days to csv files.';

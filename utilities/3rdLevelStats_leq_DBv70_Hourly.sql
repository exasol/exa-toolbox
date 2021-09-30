/*
        The script to export hourly statistics for the last x days (x is a script parameter) for investigation by support.
        This is part 3 of 3-part script set for Exasol Database versions up to 7.0.
        
        Originally mentioned in article https://community.exasol.com/t5/database-features/statistics-export-for-support-v6-x/ta-p/1778
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

export (select * from "$EXA_MONITOR_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'monitor_hourly.csv' truncate;
export (select * from EXA_USAGE_HOURLY where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'usage_hourly.csv' truncate;
export (select * from "$EXA_SQL_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'sql_hourly.csv' truncate;
export (select * from "$EXA_PROFILE_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'profile_hourly.csv' truncate;
export (select * from "$EXA_DB_SIZE_HOURLY" where INTERVAL_START > ADD_DAYS(systimestamp, -&days)) into local csv file 'db_size_hourly.csv' truncate;
export (select * from "$EXA_SYSTEM_EVENTS" where MEASURE_TIME >= (SELECT LEAST(ADD_DAYS(systimestamp, -&days), MAX(MEASURE_TIME)) FROM "$EXA_SYSTEM_EVENTS" WHERE EVENT_TYPE='STARTUP')) into local csv file 'system_events.csv' truncate;
export (select param_value from exa_metadata where param_name = 'databaseProductVersion') into local csv file 'database_version.csv' truncate;

select 'exported hourly statistics of last &days days to monitor_hourly.csv, usage_hourly.csv, sql_hourly.csv, profile_hourly.csv, db_size_hourly.csv, system_events.csv, database_version.csv';

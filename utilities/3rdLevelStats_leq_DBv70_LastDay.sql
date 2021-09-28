/*
        The script to export statistics of the last day for investigation by support.
        This is part 2 of 3-part script set for Exasol Database versions up to 7.0.
        
        Originally mentioned in article https://community.exasol.com/t5/database-features/statistics-export-for-support-v6-x/ta-p/1778
*/

set autocommit off;

alter session set NLS_DATE_FORMAT = 'YYYY-MM-DD';
alter session set NLS_FIRST_DAY_OF_WEEK = 7;
alter session set NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH:MI:SS.FF6';
alter session set NLS_NUMERIC_CHARACTERS = '.,';
alter session set NLS_DATE_LANGUAGE = 'ENG';
alter session set QUERY_TIMEOUT = 0;
alter session set SQL_PREPROCESSOR_SCRIPT = '';

export (select * from "$EXA_MONITOR_DETAILS_LAST_DAY") into local csv file 'monitor_details_last_day.csv' truncate;
export (select * from EXA_USAGE_LAST_DAY) into local csv file 'usage_last_day.csv' truncate;
export (select * from "$EXA_SQL_LAST_DAY") into local csv file 'sql_last_day.csv' truncate;
export (select * from "$EXA_PROFILE_LAST_DAY") into local csv file 'profile_last_day.csv' truncate;
export (select * from "$EXA_DB_SIZE_LAST_DAY") into local csv file 'db_size_last_day.csv' truncate;
export (select SESSION_ID,LOGIN_TIME,LOGOUT_TIME,CLIENT,DRIVER,ENCRYPTED,SUCCESS,ERROR_CODE,ERROR_TEXT from EXA_DBA_SESSIONS_LAST_DAY) into local csv file 'all_sessions.csv' truncate;
export (select * from "$EXA_SYSTEM_EVENTS" where MEASURE_TIME >= (SELECT LEAST(ADD_DAYS(systimestamp, -30), MAX(MEASURE_TIME)) FROM "$EXA_SYSTEM_EVENTS" WHERE EVENT_TYPE='STARTUP')) into local csv file 'system_events_30days.csv' truncate;
export (select * from EXA_DBA_TRANSACTION_CONFLICTS where coalesce(STOP_TIME,START_TIME) > add_hours(systimestamp, -24)) into local csv file 'transaction_conflicts.csv' truncate;
export (select param_value from exa_metadata where param_name = 'databaseProductVersion') into local csv file 'database_version.csv' truncate;

select 'exported last day statistics to monitor_details_last_day.csv, usage_last_day.csv, sql_last_day.csv, profile_last_day.csv, db_size_last_day.csv, all_sessions.csv, system_events_30days.csv, transaction_conflicts.csv, database_version.csv';

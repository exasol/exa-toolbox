/*
        The script to export statistics on indices and database objects for investigation by support.
        This is part 1 of 3-part script set for Exasol Database versions up to 7.0.
        
        Originally mentioned in article https://exasol.my.site.com/s/article/Statistics-export-for-support?language=en_US
*/

set autocommit off;

alter session set NLS_DATE_FORMAT = 'YYYY-MM-DD';
alter session set NLS_FIRST_DAY_OF_WEEK = 7;
alter session set NLS_TIMESTAMP_FORMAT = 'YYYY-MM-DD HH:MI:SS.FF6';
alter session set NLS_NUMERIC_CHARACTERS = '.,';
alter session set NLS_DATE_LANGUAGE = 'ENG';
alter session set QUERY_TIMEOUT = 0;
alter session set SQL_PREPROCESSOR_SCRIPT = '';

export (select * from "EXA_VOLUME_USAGE") into local csv file 'exa_volume_usage.csv' truncate;
export (select * from "$EXA_INDICES") into local csv file 'exa_indices.csv' truncate;
export (select * from "$EXA_COLUMN_SIZES") into local csv file 'exa_column_sizes.csv' truncate;
export (select * from "$EXA_COLUMN_STATISTICS") into local csv file 'exa_column_statistics.csv' truncate;

select 'exported object statistics to exa_volume_usage.csv, exa_indices.csv, exa_column_sizes.csv, exa_column_statistics.csv';

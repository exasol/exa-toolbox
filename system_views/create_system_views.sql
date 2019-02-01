CREATE SCHEMA IF NOT EXISTS EXA_TOOLBOX;

CREATE OR REPLACE VIEW EXA_TOOLBOX.SCHEMA_SIZES AS
select
OBJECT_NAME 'Schema Name',
case when RAW_OBJECT_SIZE > 0 then cast(RAW_OBJECT_SIZE / 1024 / 1024 / 1024 as DECIMAL(36,5)) else  RAW_OBJECT_SIZE end 'RAW Size in GiB [uncompressed]',
case when MEM_OBJECT_SIZE > 0 then cast(MEM_OBJECT_SIZE / 1024 / 1024 / 1024 as DECIMAL(36,5)) else MEM_OBJECT_SIZE end 'MEM Size in GiB [compressed]',
case when MEM_OBJECT_SIZE > 0 then cast(RAW_OBJECT_SIZE / MEM_OBJECT_SIZE as DECIMAL(15,5)) else 0 end   'Compression [RAW/MEM]',
CREATED 'Created',
LAST_COMMIT 'Last Commit'
from
SYS.EXA_ALL_OBJECT_SIZES
where
OBJECT_TYPE = 'SCHEMA' 
ORDER BY MEM_OBJECT_SIZE desc;

CREATE OR REPLACE VIEW EXA_TOOLBOX.TABLE_SIZES_TOP_100 AS
select
ROOT_NAME 'Schema name',
OBJECT_NAME 'Table Name',
cast(RAW_OBJECT_SIZE / 1024 / 1024 / 1024 as DECIMAL(36,5)) 'RAW Size in GiB [uncompressed]',
cast(MEM_OBJECT_SIZE / 1024 / 1024 / 1024 as DECIMAL(36,5)) 'MEM Size in GiB [compressed]',
cast(RAW_OBJECT_SIZE/ MEM_OBJECT_SIZE as DECIMAL(15,5)) 'Compression [RAW/MEM]',
CREATED 'Created',
LAST_COMMIT 'Last Commit'
from
SYS.EXA_ALL_OBJECT_SIZES
where OBJECT_TYPE = 'TABLE'
ORDER BY MEM_OBJECT_SIZE desc
LIMIT 100;

CREATE OR REPLACE VIEW  EXA_TOOLBOX.AUDITING_LONG_RUNNING_DML_LAST24HOURS  AS
SELECT
	SESSION_ID 'Session ID',
	STMT_ID 'Stmt ID',
	COMMAND_NAME 'Command name',
	COMMAND_CLASS 'Command class',
	DURATION 'Duration [sec]',
	START_TIME 'Start time',
	STOP_TIME 'Stop time',
	CPU 'CPU %',
	TEMP_DB_RAM_PEAK 'Temp DB RAM Peak [MiB]',
	HDD_READ 'HDD read [MiB/sec]',
	HDD_WRITE 'HDD write [MiB/sec]',
	NET 'Network [MiB/sec]',
	SUCCESS 'Success',
	ERROR_CODE 'Error code',
	ERROR_TEXT 'Error text',
	SCOPE_SCHEMA 'Scope schema',
	PRIORITY 'Priority',
	NICE 'Nice',
	RESOURCES 'Resources %',
	ROW_COUNT 'Row count',
	EXECUTION_MODE 'Execution mode',
	SQL_TEXT 'SQL text'
FROM
	EXA_STATISTICS.EXA_DBA_AUDIT_SQL
WHERE START_TIME >=  add_hours(CURRENT_TIMESTAMP,-24)   AND COMMAND_CLASS = 'DML'
ORDER BY DURATION desc
LIMIT 1000;

CREATE OR REPLACE VIEW  EXA_TOOLBOX.AUDITING_LONG_RUNNING_DQL_LAST24HOURS  AS
SELECT
	SESSION_ID 'Session ID',
	STMT_ID 'Stmt ID',
	COMMAND_NAME 'Command name',
	COMMAND_CLASS 'Command class',
	DURATION 'Duration [sec]',
	START_TIME 'Start time',
	STOP_TIME 'Stop time',
	CPU 'CPU %',
	TEMP_DB_RAM_PEAK 'Temp DB RAM Peak [MiB]',
	HDD_READ 'HDD read [MiB/sec]',
	HDD_WRITE 'HDD write [MiB/sec]',
	NET 'Network [MiB/sec]',
	SUCCESS 'Success',
	ERROR_CODE 'Error code',
	ERROR_TEXT 'Error text',
	SCOPE_SCHEMA 'Scope schema',
	PRIORITY 'Priority',
	NICE 'Nice',
	RESOURCES 'Resources %',
	ROW_COUNT 'Row count',
	EXECUTION_MODE 'Execution mode',
	SQL_TEXT 'SQL text'
FROM
	EXA_STATISTICS.EXA_DBA_AUDIT_SQL
WHERE START_TIME >=  add_hours(CURRENT_TIMESTAMP,-24)   AND COMMAND_CLASS = 'DQL'
ORDER BY DURATION desc
LIMIT 1000;

CREATE OR REPLACE VIEW EXA_TOOLBOX.PROFILE_OF_RUNNING_QUERIES AS
SELECT
	SESSION_ID 'Session ID',
	STMT_ID 'Stmt ID',
	COMMAND_NAME 'Command name',
	COMMAND_CLASS 'Command class',
	PART_ID 'Part ID',
	PART_NAME 'Part name',
	PART_INFO 'Part info',
	OBJECT_SCHEMA 'Object schema',
	OBJECT_NAME 'Object name',
	to_char(OBJECT_ROWS,'999G999G999G999G999G999G999G999') 'Object rows',
	to_char(OUT_ROWS,'999G999G999G999G999G999G999G999') 'Out rows',
	DURATION 'Duration [sec]',
	CPU 'CPU %',
	TEMP_DB_RAM_PEAK 'Temp DB RAM Peak [MiB]',
	HDD_READ 'HDD read [MiB/sec]',
	HDD_WRITE 'HDD write [MiB/sec]',
	NET 'Network [MiB/sec]',
	REMARKS 'Remarks',
	SQL_TEXT 'SQL text'
FROM
	EXA_STATISTICS.EXA_DBA_PROFILE_RUNNING;



CREATE OR REPLACE VIEW EXA_TOOLBOX.GENERAL_SYSTEM_INFO AS
select
param_name, param_value
from
SYS.EXA_METADATA
where
PARAM_NAME in
(
'databaseProductVersion',
'databaseName'
)
union all

select
'Nodes' , cast(NODES   as VARCHAR(10))
from
EXA_SYSTEM_EVENTS
where EVENT_TYPE = 'STARTUP'
and measure_time = (select
max(measure_time)
from EXA_SYSTEM_EVENTS where EVENT_TYPE = 'STARTUP'
)

union all

select
'DBRAM (GiB)' , cast(DB_RAM_SIZE   as VARCHAR(10))
from
EXA_SYSTEM_EVENTS
where EVENT_TYPE = 'STARTUP'
and measure_time = (select
max(measure_time)
from EXA_SYSTEM_EVENTS where EVENT_TYPE = 'STARTUP'
)

union all

select
PARAM_NAME, PARAM_VALUE
from
"EXA_COMMANDLINE"
where
PARAM_NAME in
(
'soft_replicationborder_in_kb',
'soft_replicationborder_in_numrows',
'disableViewOptimization',
'disableIndexIteratorScan',
'auditing_enabled',
'expiration_advanced_edition_features',
'expiration_standard_edition_features'
)

order by 1;

CREATE OR REPLACE VIEW EXA_TOOLBOX.SESSIONS AS
select
	SESSION_ID 'Session ID',
	case when SESSION_ID = CURRENT_SESSION THEN true end 'Current Session',
	case when instr(activity,' rows')!=0 and is_number(substr(activity,0,length(activity)-length(' rows'))) then to_char(to_number(substr(activity,0,length(activity)-length(' rows'))),'999G999G999G999G999G999G999G999') || ' rows' else activity end  'Activity',
	USER_NAME 'User name',
	STATUS 'Status',
	COMMAND_NAME 'Command name',
	STMT_ID 'Statement ID',
	DURATION 'Duration',
	QUERY_TIMEOUT 'Query timeout [sec]',
	concat(TEMP_DB_RAM,' MiB') 'Temporary DB RAM',
	LOGIN_TIME 'Login time',
	CLIENT 'Client',
	DRIVER 'Driver',
	ENCRYPTED 'Encrpyted',
	HOST 'Host',
	OS_USER 'OS user',
	OS_NAME 'OS name',
	SCOPE_SCHEMA 'Scope schema',
	PRIORITY 'Priority',
	NICE 'Nice',
	case when RESOURCES is not null then RESOURCES || '%' end 'Resources',
	SQL_TEXT 'SQL text'
from
	EXA_DBA_SESSIONS
order by session_id;

CREATE OR REPLACE VIEW EXA_TOOLBOX.DB_SIZE_LAST_DAY AS
SELECT
   MEASURE_TIME 'Time',
   RAW_OBJECT_SIZE  'RAW uncompressed [GiB]',
   MEM_OBJECT_SIZE 'MEM compressed [GiB]',
   case when MEM_OBJECT_SIZE > 0 then cast(RAW_OBJECT_SIZE/MEM_OBJECT_SIZE as DECIMAL(18,3)) else 0 end 'Compression RAW/MEM',
   AUXILIARY_SIZE  'Auxiliary/Indices [GiB]',
   STATISTICS_SIZE 'Statistics [GiB]',
   RECOMMENDED_DB_RAM_SIZE 'Recommended DB RAM [GiB]',
   STORAGE_SIZE 'Storage [GiB]',
   USE 'Use in %',
   OBJECT_COUNT 'Object count'
FROM
   EXA_STATISTICS.EXA_DB_SIZE_LAST_DAY
order by 1 desc;

CREATE OR REPLACE VIEW EXA_TOOLBOX.DB_SIZE_DAILY AS
SELECT
	INTERVAL_START 'Time',
	RAW_OBJECT_SIZE_AVG 'RAW uncompressed AVG [GiB]',
	RAW_OBJECT_SIZE_MAX  'RAW uncompressed MAX [GiB]',
	MEM_OBJECT_SIZE_AVG  'MEM compressed AVG [GiB]',
	MEM_OBJECT_SIZE_MAX  'MEM compressed MAX [GiB]',
	case when MEM_OBJECT_SIZE_AVG > 0 then  cast(RAW_OBJECT_SIZE_AVG/MEM_OBJECT_SIZE_AVG as DECIMAL(18,3)) else null end 'Compression AVG RAW/MEM',
	AUXILIARY_SIZE_AVG  'Auxiliary/Indices AVG [GiB]',
	AUXILIARY_SIZE_MAX  'Auxiliary/Indices MAX [GiB]',
	STATISTICS_SIZE_AVG 'Statistics AVG [GiB]',
	STATISTICS_SIZE_MAX 'Statistics MAX [GiB]',
	RECOMMENDED_DB_RAM_SIZE_AVG 'Recommended DB RAM AVG [GiB]',
	RECOMMENDED_DB_RAM_SIZE_MAX  'Recommended DB RAM MAX [GiB]',
	STORAGE_SIZE_AVG 'Storage AVG [GiB]',
	STORAGE_SIZE_MAX 'Storage MAX [GiB]',
	USE_AVG 'Use in % AVG',
	USE_MAX 'Use in % MAX',
	OBJECT_COUNT_AVG 'Object count AVG',
	OBJECT_COUNT_MAX 'Object count MAX'
FROM
	EXA_STATISTICS.EXA_DB_SIZE_DAILY
WHERE TRUNC(INTERVAL_START) >= add_days(current_date,-31)
order by 1 desc;

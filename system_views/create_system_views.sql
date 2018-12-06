CREATE SCHEMA IF NOT EXISTS EXA_TOOLBOX;

CREATE OR REPLACE VIEW SCHEMA_SIZES AS
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

CREATE OR REPLACE VIEW TABLE_SIZES_TOP_100 AS
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

CREATE OR REPLACE VIEW  AUDITING_LONG_RUNNING_DML_LAST24HOURS  AS
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

CREATE OR REPLACE VIEW  AUDITING_LONG_RUNNING_DQL_LAST24HOURS  AS
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

CREATE OR REPLACE VIEW PROFILE_OF_RUNNING_QUERIES AS
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
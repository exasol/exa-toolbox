--/
CREATE OR REPLACE LUA SCRIPT DB_WARMUP RETURNS TABLE AS
 
    --Script uses Query wrapper library https://github.com/exasol/etl-utils 
    import('ETL.query_wrapper','qw')

    wrapper = qw.new('ETL.job_log', 'ETL.job_details', 'database warmup')
    
    --Query Auditing to get the Queris which you would like to use to warm up the system
    --The following example takes all Queries from Tableau for a certain user executed in the last 5 days limited to 100 SELECT queries
    --Adapt to your scenario
    for sql_text in wrapper:query_values([[
        select SQL_TEXT
        from
        "EXA_STATISTICS"."EXA_DBA_AUDIT_SESSIONS"
        join
        "EXA_STATISTICS"."EXA_DBA_AUDIT_SQL" using (session_id)
        where 
        "EXA_DBA_AUDIT_SESSIONS"."CLIENT" like '%Tableau%' and 
        trunc("EXA_DBA_AUDIT_SQL"."START_TIME") >= add_days(CURRENT_DATE, -5) and 
        "EXA_DBA_AUDIT_SQL"."COMMAND_NAME" = 'SELECT' and USER_NAME = 'EXASOL_TB' and
        SQL_TEXT not like 'SELECT 1'
        order by start_time desc limit 1000
     ]] ) do

        -- Executing all the queries from Auditing 
        wrapper:query(sql_text)

    end

    return wrapper:finish()
/
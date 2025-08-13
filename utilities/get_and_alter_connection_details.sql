/* 
    This tool will help you to generate proper ALTER CONNECTION statements for your existing Exasol connection objects (incl. USER_NAME & PW) in case you have to change e.g. only the IP Address or Hostname in the connection string.
    See also:
    https://docs.exasol.com/db/latest/database_concepts/udf_scripts/lua.htm#Accessin
    https://docs.exasol.com/db/latest/sql/alter_connection.htm
    THIS SHOULD ONLY BE USED BY EXPERIENCED EXASOL USERS/DBA!
    PLEASE NOTE THAT THIS IS AN OPEN SOURCE PROJECT WHICH IS NOT OFFICIALLY SUPPORTED BY EXASOL!
    WE WILL TRY TO HELP YOU AS MUCH AS POSSIBLE, BUT CAN'T GUARANTEE ANYTHING SINCE THIS IS NOT AN OFFICIAL EXASOL PRODUCT!
    FEEL FREE TO ADJUST IT AND HANDLE IT WITH CARE ON YOUR OWN RISK!
*/


/* Create one example EXA and one SQL Server connection if not already present and grant it to anyone for test purposes.
   See also:
   https://docs.exasol.com/db/latest/loading_data/connect_sources/exasol.htm
   https://docs.exasol.com/db/latest/loading_data/connect_sources/sql_server.htm

   Uncomment the following statements, if needed:
*/
--CREATE OR REPLACE CONNECTION EXAMPLE_CONNECTION_EXA TO '172.16.175.146/nocertcheck:8563' USER 'exauser' IDENTIFIED BY 'sdasdha77234nd';
--CREATE OR REPLACE CONNECTION EXAMPLE_CONNECTION_SQLSERVER TO 'jdbc:sqlserver://mysqlserver.somewhere.com:1433;databaseName=TESTDB1;instance=v1' USER 'sqluser' IDENTIFIED BY 'my173hsbxwrwew';
--GRANT CONNECTION EXAMPLE_CONNECTION_EXA TO PUBLIC;
--GRANT CONNECTION EXAMPLE_CONNECTION_SQLSERVER TO PUBLIC;

/* Check, if your connections work before you change them.
   Pre-requisites, see here:
   https://docs.exasol.com/db/latest/loading_data/connect_sources/exasol.htm
   https://docs.exasol.com/db/latest/loading_data/connect_sources/sql_server.htm

   Uncomment the following statements, if needed:
*/
--SELECT * FROM (IMPORT FROM EXA AT EXAMPLE_CONNECTION_EXA STATEMENT 'select ''Connection works'' ');
--SELECT * FROM (IMPORT FROM JDBC AT EXAMPLE_CONNECTION_SQLSERVER STATEMENT 'select ''Connection works'' ');


-- Create a schema that holds the script.
-- Please change the schema name to your needs and change it also in the following statements.

CREATE SCHEMA IF NOT EXISTS ADMIN_TOOLS;


-- Create the SCALAR Lua UDF get_connection_details that takes the connection name as input and emits its details over the "exa.get_connection" method.

--/
CREATE OR REPLACE LUA SCALAR SCRIPT ADMIN_TOOLS.get_connection_details(conn_name VARCHAR(128))
EMITS (
  CONNECTION_NAME     VARCHAR(128),
  CONNECTION_STRING   VARCHAR(4000),
  USER_NAME           VARCHAR(4000),
  PASSWORD            VARCHAR(4000)
)
AS
function run(ctx)
  local name = ctx.conn_name
  if name == nil then
    return
  end
  local c = exa.get_connection(name)  -- available in UDF runtime
  local conn_str = nil
  if c then
    -- accommodate version differences: sometimes 'string', sometimes 'address'
    conn_str = c.string or c.address or c.connection_string
  end
  ctx.emit(
    name,
    conn_str,
    c and c.user or NULL,
    c and c.password or NULL
  )
end
/

-- Simple SELECT to call the Lua UDF for all defined connections.
-- If you do not have SELECT ANY DICTIONARY rights, you can use EXA_ALL_CONNECTIONS instead of EXA_DBA_CONNECTIONS.

SELECT ADMIN_TOOLS.get_connection_details(CONNECTION_NAME)
FROM EXA_DBA_CONNECTIONS
ORDER BY 1;


-- A SELECT that automatically generates the syntactically correct ALTER CONNECTION statements of all existing connections.
-- Please copy them out manually into a new SQL Commander Window or text file, alter the wanted attributes and run the statements manually.
-- If you do not have SELECT ANY DICTIONARY rights, you can use EXA_ALL_CONNECTIONS instead of EXA_DBA_CONNECTIONS.

SELECT 'ALTER CONNECTION ' || CONNECTION_NAME || ' TO ''' || CONNECTION_STRING || ''' USER ''' || USER_NAME || ''' IDENTIFIED BY ''' || PASSWORD || '''; ' AS ALTER_CONNECTION_STATEMENT
FROM (
SELECT ADMIN_TOOLS.get_connection_details(CONNECTION_NAME)
FROM EXA_DBA_CONNECTIONS
ORDER BY 1
);

-- A SELECT that finds all distinct SQLSERVER_URLs that are used in all connections objects within the CONNECTION_STRING.
-- If you do not have SELECT ANY DICTIONARY rights, you can use EXA_ALL_CONNECTIONS instead of EXA_DBA_CONNECTIONS.

SELECT DISTINCT REGEXP_SUBSTR(CONNECTION_STRING, '(?<=//)[^:]+(?=:)', 1, 1) AS SQLSERVER_URL
FROM (
SELECT ADMIN_TOOLS.get_connection_details(CONNECTION_NAME)
FROM EXA_DBA_CONNECTIONS
)
WHERE lower (CONNECTION_STRING)  LIKE '%jdbc:sqlserver%'
ORDER BY 1
;

-- A SELECT that generates nslookup statements for all distinct SQLSERVER_URLs that are used in all connections objects within the CONNECTION_STRING.
-- This helps you to easily check, whether your DNS server can correctly resolve the specified host address.
-- If you do not have SELECT ANY DICTIONARY rights, you can use EXA_ALL_CONNECTIONS instead of EXA_DBA_CONNECTIONS.

SELECT DISTINCT 'nslookup ' ||  REGEXP_SUBSTR(CONNECTION_STRING, '(?<=//)[^:]+(?=:)', 1, 1) AS NSLOOKUP_STATEMENT
FROM (
SELECT ADMIN_TOOLS.get_connection_details(CONNECTION_NAME)
FROM EXA_DBA_CONNECTIONS
)
WHERE lower (CONNECTION_STRING)  LIKE '%jdbc:sqlserver%'
ORDER BY 1
;

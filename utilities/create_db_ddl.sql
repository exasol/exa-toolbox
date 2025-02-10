/*
		This script creates DDL statements for an entire database. 
		The DDL are presented as a single-column result-set and are ready for copy/paste into a text editor or SQL-editor for saving.
        
        Originally mentioned in article https://exasol.my.site.com/s/article/Create-DDL-for-the-entire-Database?language=en_US
*/

CREATE SCHEMA IF NOT EXISTS exa_toolbox;
OPEN SCHEMA exa_toolbox;

--/
CREATE OR REPLACE LUA SCRIPT exa_toolbox.CREATE_DB_DDL (add_user_structure,add_rights,store_in_table) RETURNS TABLE AS
/*
/*
PARAMETERS:
        - add_user_structure: boolean
          If true then DDL for adding roles and users is added (at the top, before everything else).
        - add_rights: boolean
          If true then DDL for user & role privileges is added (at the bottom, after everything else).
        - store_in_table: boolean
          If true, the entire output is stored in the table "DB_HISTORY"."DATABASE_DDL" before the output is diplayed.
ISSUE [PRJ-1156]:
Lua script - generates DDL for all objects in a database:
        - all schemas
        - all tables, constraints, distribution keys.
        - all views (paying respect to dependencies)
        - all scripts
        - all functions
        - all connections
        - all users, roles, rights
        - all virtual schemas
PREREQUISITES:
        - user executing the script needs "SELECT ANY DICTIONARY" privilege
LIMITATIONS:
        - views and functions which are created in a renamed schema will cause an error on DDL execution
        - GRANTOR of all privileges will be the user that runs the SQL code returned by the script
        - passwords of all users will be 'Start123', except for connections where passwords will be left empty
        - functions with dependencies will not be created in the appropriate order
        - UDF scripts with delimited identifiers (in- or output) will cause an error on DDL execution
        - UDF scripts using languages other than the defaults will fail if bucketfs is not set up beforehand
        - Virtual Schemas will not be created if the required drivers are not installed beforehand
TODO:
        - omit privs for invalid views?
CHANGE LOG:
2018-06-15
        - Script now creates DDL for users who are authenticated using LDAP (using force).
        - Added OPEN SCHEMA commands before Script DDL
        - Allowed option to write the data into a table (only one-line supported). To change the table location, please change lines 670 and 673
2018-08-30
        - return in row is simply not possible, the output is longer than 2.000.000
        - the same applies to writing in a single table column
        - return is splitted in parts the same way the table is written
        - ddl.sql file remains same (export with group_concat)
        - fixed creation errors with added 'or replace' to get a newer version installed
2018-12-28
        - Enabled versioning for 6.1 (still compatible for version 6)
        - Fixed Kerberos authentication (no lines need to be uncommented)
        - check that calling user has "SELECT ANY DICTIONARY" privilege
        - 6.1 FEATURE: Added support for Custom Priority groups
        - 6.1 FEATURE: Added support for impersonation
        - 6.1 FEATURE: Added support for partition keys
        - 6.1 FEATURE: Added support for schema quotas
        - 6.1 FEATURE: Added support for password policies on system-wide or user-based
        - Adds ALTER SYSTEM/SESSION commands to set the parameters as they were on the old system
        - Virtual schemas are created
        - Script execution now works in DBVisualizer
        - Removed return_in_one_row parameter
        - Removed nulls from the output
        - Invalid views WILL be created
2019-01-30
        - Added new LUA script exa_toolbox."RESTORE_SYS"
        - Replace LUA script exa_toolbox."BACKUP_SYS"
        - Format. Removed blank lines. Adjust Tab and spaces
2019-03-22
        - Added handling of DDL that was over 2 million characters
        - Fixed bug regarding empty connection strings in connection objects
2021
        - Added consumer groups (v7.0)
2021-10-07
        - Changes in EXA_Parameters, new values to consider
        - Fix compile error against 7.1
        - Added new options IDLE_TIMEOUT and QUERY_TIMEOUT to consumer groups
2021-12-10
        - Changed add_script according to community request (handle duplicate names)
2022-01-07
        - Added snapshot execution (for 6.2 and 7.0 users)
2022-08-30
		- Improved delimitation of identifiers
		- Added support for OpenID users
		- Simplified some queries and replaced some loops with Lua's 1
		- Accounted the split of EXA_DBA_VIRTUAL_SCHEMA.ADAPTER_SCRIPT column in 8.0
		- Fixed schemas order
		- Changed backup format from .csv to .csv.gz
2022-11-27
		- Added group_concat for obj-grants (reduces file size and exec time on restore)
2023-06-26
		- Grants on invalid views are now included by default.
		Executing GRANT on an invalid view requires system privilege "GRANT ANY OBJECT PRIVILEGE".
		If users want to exclude grants on invalid views they need to adapt the part of script responsible for object privileges.
*/

-- sqlstring concatination
function check_version()
        version_suc, version = pquery([[/*snapshot execution*/SELECT SUBSTR(PARAM_VALUE, 0, 3) VERSION_NUMBER, PARAM_VALUE version_full FROM EXA_METADATA WHERE PARAM_NAME = 'databaseProductVersion']])

        if not (version_suc) then
                error('error determining version')
        else
                version_short = version[1].VERSION_NUMBER
                version_full = version[1].VERSION_FULL
        end
end

function sqlstr_add(str)
        sqlstr = sqlstr..str
end

-- set an empty sqlstring
function sqlstr_flush()
        sqlstr = ''
end

-- set an empty ddl
function ddl_flush()
        ddl = ''
end
-- adds sqlstring to dll or adds sqlstring to summary table
function sqlstr_commit()
        ddllength=string.len(ddl)+string.len(sqlstr)
          -- Check if the length of the total string is greater than 2,000,000, insert into the table first to avoid string being too long
        if ddllength > 2000000 then
                write_table('SPLIT', ddl)
                ddl_flush()
        end
        ddl = ddl..sqlstr
        sqlstr_flush()
end

-- add linefeed to sqlstring
function sqlstr_lf()
                sqlstr_add('\n')
end

function ddl_endings()
        sqlstr_flush()
        sqlstr_lf()
        sqlstr_add('COMMIT;')
        sqlstr_commit()
end

function add_all_connections()                  -- ADD ALL CONNECTIONS -------------------------------------------------------------------------------------

        ac1_success,ac1_res = pquery([[/*snapshot execution*/select CONNECTION_NAME, nvl(CONNECTION_STRING, ' ') as CONNECTION_STRING,
        USER_NAME, CREATED, CONNECTION_COMMENT  from EXA_DBA_CONNECTIONS]])
        if not ac1_success then
                error('Error at ac1')
        end
        sqlstr_add('-- CONNECTIONS --------------------------------------------------------------------\n')
        sqlstr_lf()
--      if (#ac1_res) == 0 then
--              sqlstr_add('\t--no connections specified\n')
--      end
        for i=1,(#ac1_res) do
                sqlstr_add('\tCREATE CONNECTION "'..ac1_res[i].CONNECTION_NAME..'" \n\t\tTO \''..ac1_res[i].CONNECTION_STRING..'\'')
                if (ac1_res[i].USER_NAME ~= NULL) then
                        sqlstr_add('\n\t\tUSER \''..ac1_res[i].USER_NAME..'\' \n\t\t IDENTIFIED BY \'\';\n\n')

                else
                        sqlstr_add(';\n\n')
                end
                sqlstr_commit()
        end
        sqlstr_lf()
        sqlstr_commit()
end


function add_all_roles()                                        -- ADD ALL ROLES -----------------------------------------------------------------------------------------
        ar1_success, ar1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_ROLES]])
        if not ar1_success then
                error('Error at ar1')
        end
        if (#ar1_res) > 2 then -- if more than system roles 'public' and 'dba'
--              sqlstr_flush()
                sqlstr_add('-- ROLES --------------------------------------------------------------------\n')
                sqlstr_commit()
                sqlstr_lf()
                for i=1, (#ar1_res) do
                        if (ar1_res[i].ROLE_NAME~='PUBLIC' and ar1_res[i].ROLE_NAME~='DBA') then
                                sqlstr_add('\tCREATE ROLE "'..ar1_res[i].ROLE_NAME..'";\n')
                                if ar1_res[i].ROLE_COMMENT ~= null then
                                        sqlstr_commit()
                                        sqlstr_add('\t\tCOMMENT ON ROLE "'..ar1_res[i].ROLE_NAME..'" IS \''..ar1_res[i].ROLE_COMMENT..'\';\n')
                                end
                        end
                        sqlstr_commit()
                end
                sqlstr_add('\n')
        else
                        sqlstr_add('-- ROLES --------------------------------------------------------------------\n')
                        sqlstr_lf()
                        sqlstr_add('\t-- only system roles defined.\n')
                        sqlstr_lf()
                        sqlstr_commit()
        end
end

function add_all_users()                                        -- ADD ALL USERS -----------------------------------------------------------------------------------------

        aau1_success, aau1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_USERS]])
        if not aau1_success then
                error('Error at aau1')
        end
--      sqlstr_flush()
        sqlstr_add('-- USERS --------------------------------------------------------------------\n')
        sqlstr_commit()
        sqlstr_lf()
        if (#aau1_res) > 1 then -- if more than only user 'sys'
                for i=1,(#aau1_res) do
                        if aau1_res[i].USER_NAME ~= 'SYS' then
                                sqlstr_add('\tCREATE USER "'..aau1_res[i].USER_NAME..'\"')
                                if aau1_res[i].DISTINGUISHED_NAME~=null then  -- if LDAP info given, create username with ldap, otherwise use password
									ldap_string = (string.gsub(aau1_res[i].DISTINGUISHED_NAME, "'", "''"))
									sqlstr_add(' IDENTIFIED AT LDAP AS \''..ldap_string..'\' FORCE;\n')
                                elseif (aau1_res[i].KERBEROS_PRINCIPAL)~=null then  -- if Kerberos info given, include Kerberos information
									sqlstr_add(' IDENTIFIED BY KERBEROS PRINCIPAL \''..aau1_res[i].KERBEROS_PRINCIPAL..'\';\n')
								elseif (version_short >= ('7.1')) then
									if (aau1_res[i].OPENID_SUBJECT)~=null then  -- if OpenID info given, include OpenID information
										sqlstr_add(' IDENTIFIED BY OPENID SUBJECT \''..aau1_res[i].OPENID_SUBJECT..'\';\n')
									else
										sqlstr_add(' IDENTIFIED BY "Start123";\n')
									end
                                else
                                       sqlstr_add(' IDENTIFIED BY "Start123";\n')

                                end
                                if aau1_res[i].USER_COMMENT ~= NULL then
                                        sqlstr_commit()
                                        sqlstr_add('\t\tCOMMENT ON USER "'..aau1_res[i].USER_NAME..'"'.." IS '"..aau1_res[i].USER_COMMENT.."';\n")
                                end

                                -- change V7
                                if (version_short >= ('7.0')) then
                                    sqlstr_commit()
                                    if aau1_res[i].USER_CONSUMER_GROUP~=null then
                                        sqlstr_add('\t\tALTER USER "'..aau1_res[i].USER_NAME..'" SET CONSUMER_GROUP = "'..aau1_res[i].USER_CONSUMER_GROUP..'";\n')
                                    end
                                 else
                                    if aau1_res[i].USER_PRIORITY~=null then
                                        sqlstr_commit()
                                        if (version_short ~= ('6.0')) and (version_short ~= ('5.0')) then
                                            sqlstr_add('\t\tGRANT PRIORITY GROUP '..aau1_res[i].USER_PRIORITY..' TO "'..aau1_res[i].USER_NAME..'";\n')
                                        else
                                            sqlstr_add('\t\tGRANT PRIORITY '..aau1_res[i].USER_PRIORITY..' TO "'..aau1_res[i].USER_NAME..'";\n')
                                        end
                                     end
                                  end

                                if (version_short ~= ('6.0')) and (version_short ~= ('5.0'))  then
                                        if aau1_res[i].PASSWORD_EXPIRY_POLICY ~= null then

                                                sqlstr_commit()
                                                sqlstr_add('\tALTER USER "'..aau1_res[i].USER_NAME..'" SET PASSWORD_EXPIRY_POLICY=\''.. aau1_res[i].PASSWORD_EXPIRY_POLICY..'\' ;\n')
                                        end
                                end
                        end
                        sqlstr_commit()
                end
        sqlstr_add('\n')
        else
                sqlstr_add('\t-- only system users defined.\n')
                sqlstr_lf()
                sqlstr_commit()

        end

end

function add_all_rights()                                       -- ADD ALL RIGHTS -----------------------------------------------------------------------------------------

        -- role privileges

        art1_success, art1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_ROLE_PRIVS WHERE NOT (GRANTEE='SYS' AND GRANTED_ROLE='DBA')]])
        if not art1_success then
                error('Error in art1')
        end
        sqlstr_flush()
        sqlstr_add('-- RIGHTS --------------------------------------------------------------------\n')
        sqlstr_lf()
  		sqlstr_commit()
        sqlstr_add('\t--Please note that the grantor & owner of all grants will be the user who runs the script!\n')
        sqlstr_lf()
		sqlstr_commit()
        if (#art1_res) >0 then
                for i=1,(#art1_res) do
                        sqlstr_add('\tGRANT "'..art1_res[i].GRANTED_ROLE..'" TO "'..art1_res[i].GRANTEE..'"')
                        if art1_res[i].ADMIN_OPTION then
                                sqlstr_add(' WITH ADMIN OPTION')
                        end
                        sqlstr_add(';\n')
                        sqlstr_commit()
                end
        else
                sqlstr_add('\t-- No user is granted any role except for standard.\n')
                sqlstr_lf()
                sqlstr_commit()
        end

        -- system privileges

        art12_success, art12_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_SYS_PRIVS WHERE NOT GRANTEE in ('SYS', 'DBA')]])
        if not art12_success then
                error('Error in art12')
        elseif (#art12_res)>0 then
                sqlstr_flush()
                for i=1,(#art12_res)    do
                        sqlstr_add('\tGRANT '..art12_res[i].PRIVILEGE..' TO "'..art12_res[i].GRANTEE..'";\n')
                        sqlstr_add('\n')
                        sqlstr_commit()
                end
        elseif (#art12_res)==0 then
                sqlstr_flush()
                sqlstr_add('\t-- No system privileges granted to users other than SYS or DBA. \n')
                sqlstr_lf()
                sqlstr_commit()
        end

        -- object privileges
        -- Both UNION ALL branches are preserved to keep a simple possibility to define special behavior for grants on invalid views
        art2_success, art2_res = pquery([[/*snapshot execution*/SELECT 'GRANT '||GROUP_CONCAT(PRIVILEGE)||' ON "'||case when OBJECT_SCHEMA is not null then OBJECT_SCHEMA||'"."'||OBJECT_NAME||'"' else OBJECT_NAME||'"' end ||
                                        ' TO "'||GRANTEE||'"' grant_text
                                      FROM (select * from EXA_DBA_OBJ_PRIVS where object_type = 'VIEW') op
                                      /*join (select distinct COLUMN_SCHEMA, COLUMN_TABLE from exa_dba_columns where status is null) cols
                                         on cols.COLUMN_TABLE = op.OBJECT_NAME and cols.COLUMN_SCHEMA = op.OBJECT_SCHEMA*/
				      group by OBJECT_SCHEMA,OBJECT_NAME,GRANTEE
                                      union all
                                      SELECT 'GRANT '||GROUP_CONCAT(PRIVILEGE)||' ON "'||case when OBJECT_SCHEMA is not null then OBJECT_SCHEMA||'"."'||OBJECT_NAME||'"' else OBJECT_NAME||'"' end ||
                                        ' TO "'||GRANTEE||'"' grant_text
                                      FROM EXA_DBA_OBJ_PRIVS where object_type <> 'VIEW'
				      group by OBJECT_SCHEMA,OBJECT_NAME,GRANTEE]])

        if not art2_success then
                error('Error in art2')
        elseif (#art2_res)>0 then
                sqlstr_flush()
                for i=1,(#art2_res)     do
					sqlstr_add('\t'..art2_res[i].GRANT_TEXT..';\n')
					sqlstr_add('\n')
					sqlstr_commit()
                end
        elseif (#art2_res)==0 then
                sqlstr_flush()
                sqlstr_add('\t-- No object privileges granted to users other than SYS or DBA. \n')
                sqlstr_lf()
                sqlstr_commit()
        end

        -- connection privileges

        art3_success,art3_res = pquery([[/*snapshot execution*/select 'GRANT CONNECTION "' || granted_connection ||'" to ' || group_concat('"' || grantee || '"' order by grantee) || case ADMIN_OPTION when 'TRUE' then ' WITH ADMIN OPTION;' else ';' end as expr from exa_dba_connection_privs group by granted_connection, admin_option]])
        if not art3_success then
                error('Error in art3.')
        elseif (#art3_res) == 0 then
                sqlstr_flush()
                sqlstr_add('\t-- No connection privileges found. \n')
                sqlstr_lf()
                sqlstr_commit()
        else
        sqlstr_flush()
        for i=1, (#art3_res) do
                sqlstr_add('\t'..art3_res[i].EXPR..'\n')
                sqlstr_lf()
                sqlstr_commit()
        end

        end

        -- impersonation privileges (version >= 6.1)
        if (version_short >= ('6.1')) then

                art4_success, art4_res = pquery([[/*snapshot execution*/SELECT 'GRANT IMPERSONATION ON "'|| IMPERSONATION_ON || '" TO "' || GRANTEE || '";' EXPR FROM EXA_DBA_IMPERSONATION_PRIVS]])

                if not art4_success then
                        error('Error in art4: Creating impersonation privileges')
                elseif (#art3_res) == 0 then
                        sqlstr_flush()
                        sqlstr_add('\t-- No impersonation privileges found. \n')
                else
                        sqlstr_flush()
                        for i=1, (#art4_res) do
                                sqlstr_add('\t'..art4_res[i].EXPR..'\n')
                        end

                sqlstr_lf()
                sqlstr_commit()
                end
        end
end

function change_schema_owners()
                co1_success, co1_res = pquery([[/*snapshot execution*/SELECT * from EXA_SCHEMAS]])

        if not co1_success then
                error('Error in co1')
        elseif (#co1_res)==0 then
                sqlstr_flush()
                sqlstr_lf()
                sqlstr_add('-- CHANGE SCHEMA OWNERS -----------------------------------------------------------------\n')
                sqlstr_add('\t -- No user schemas in the database')
                sqlstr_commit()
                sqlstr_lf()
        elseif (#co1_res)>0 then
                sqlstr_flush()
                sqlstr_lf()
                sqlstr_add('-- CHANGE SCHEMA OWNERS -----------------------------------------------------------------\n')
                sqlstr_commit()
                sqlstr_lf()
                for i=1, (#co1_res) do
                  if co1_res[i].SCHEMA_IS_VIRTUAL then
                        sqlstr_add('\tALTER VIRTUAL SCHEMA "'..co1_res[i].SCHEMA_NAME..'" CHANGE OWNER "'..co1_res[i].SCHEMA_OWNER..'";\n')
                        sqlstr_commit()
                  else
                        sqlstr_add('\tALTER SCHEMA "'..co1_res[i].SCHEMA_NAME..'" CHANGE OWNER "'..co1_res[i].SCHEMA_OWNER..'";\n')
                        sqlstr_commit()
                  end
                end
                sqlstr_add('\n')
--              sqlstr_commit()
        end
end

function add_all_views_to_DDL()                                 --ADD ALL VIEWS--------------------------------------------------------------------------------------------

                av1_success, av1_res=pquery([[/*snapshot execution*/WITH
        all_views AS(
                with
                        view_dep AS(
                                SELECT
                                        *
                                FROM
                                        EXA_DBA_DEPENDENCIES_RECURSIVE
                                WHERE
                                        REFERENCE_TYPE = 'VIEW'
                        )
                SELECT
                        view_schema,
                        scope_schema,
                        view_name,
                        'CREATE VIEW "' || REPLACE(VIEW_SCHEMA,'"','""') || '"."' || REPLACE(VIEW_NAME,'"','""') || '"' || "$VIEW_MIGRATION_TEXT"(VIEW_TEXT) VIEW_TEXT
                FROM
                        (
                                        view_dep AS re
                                RIGHT OUTER JOIN
                                        EXA_DBA_VIEWS AS av
                                ON
                                        re.OBJECT_ID = av.VIEW_OBJECT_ID
                INNER JOIN
                    (SELECT distinct COLUMN_TABLE, COLUMN_SCHEMA from exa_dba_columns where column_object_type = 'VIEW' and status is null) cols
                ON cols.COLUMN_TABLE = av.VIEW_NAME and cols.COLUMN_SCHEMA = av.VIEW_SCHEMA
                        )
               UNION ALL
               SELECT
                        view_schema,
                        scope_schema,
                        view_name,
                        'CREATE FORCE VIEW "' || REPLACE(VIEW_SCHEMA,'"','""') || '"."' || REPLACE(VIEW_NAME,'"','""') || '"' || "$VIEW_MIGRATION_TEXT"(VIEW_TEXT) VIEW_TEXT
                FROM
                        (
                                        view_dep AS re
                                RIGHT OUTER JOIN
                                        EXA_DBA_VIEWS AS av
                                ON
                                        re.OBJECT_ID = av.VIEW_OBJECT_ID
                INNER JOIN
                    (SELECT distinct COLUMN_TABLE, COLUMN_SCHEMA from exa_dba_columns where column_object_type = 'VIEW' and status is not null) cols
                ON cols.COLUMN_TABLE = av.VIEW_NAME and cols.COLUMN_SCHEMA = av.VIEW_SCHEMA
                        )
        )
SELECT
        view_schema,
        scope_schema,
        view_name,
        rtrim(view_text, CHR(9) || CHR(10) || CHR(13))
        || CHR(13) || CHR(10) || ';'as view_text,
        count(view_name) as view_count
FROM
        all_views
GROUP BY
        view_schema,
        scope_schema,
        view_name,
        view_text
ORDER BY
        view_count,
        view_schema,
        view_name;
]])
                if not av1_success then
                        error('Error at av1')
                elseif (#av1_res) == 0 then
                        sqlstr_flush()
                        sqlstr_add('-- ALL VIEWS ---------------------------------------------------------------------------------\n')
                        sqlstr_add('\t -- No views in the database')
                        sqlstr_commit()
                        sqlstr_lf()
                elseif #av1_res > 0 then
                        sqlstr_flush()
                        sqlstr_add('-- ALL VIEWS ---------------------------------------------------------------------------------\n')
                        sqlstr_commit()
                        sqlstr_lf()
                        if av1_res[1].SCOPE_SCHEMA==NULL then
                                sqlstr_add('CLOSE SCHEMA;\n')-- close schema
                        else
                                 sqlstr_add('\nOPEN SCHEMA "'..av1_res[1].SCOPE_SCHEMA..'";\n')
                        end
                        sqlstr_add('\t'..av1_res[1].VIEW_TEXT..'\n\n')
                        sqlstr_commit()
                        for j=2, (#av1_res) do

                                if (av1_res[j].SCOPE_SCHEMA~=av1_res[j-1].SCOPE_SCHEMA)then
                                                if av1_res[j].SCOPE_SCHEMA==NULL then
                                                        sqlstr_add('CLOSE SCHEMA;\n')-- close schema
                                                else
                                                         sqlstr_add('\nOPEN SCHEMA "'..av1_res[j].SCOPE_SCHEMA..'";\n')
                                                end
                                end
                            sqlstr_add('\t'..av1_res[j].VIEW_TEXT..'\n\n')
                            sqlstr_commit()
                     end        -- for
--              sqlstr_add('\n')
--              sqlstr_lf()
--              sqlstr_commit()
          end -- else
end

function add_table_to_DDL(schema_name, tbl_name, tbl_comment)   --ADD TABLE-------------------------------------------------------------------------------------------

        sqlstr_flush()
        at1_success, at1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_COLUMNS WHERE COLUMN_SCHEMA=:s AND COLUMN_TABLE=:t ORDER BY COLUMN_ORDINAL_POSITION]], {s=schema_name, t=tbl_name})
        if not at1_success then
                error('Error at at1 -- probably table not found')
        else
                sqlstr_add([[CREATE TABLE "]]..at1_res[1].COLUMN_SCHEMA..[["."]]..at1_res[1].COLUMN_TABLE..[["(]])                                                      -- CREATE schema_name.table_name (
                distr={}
                part={}

                for i=1, (#at1_res) do
                        if i>1 then sqlstr_add(',')
                        end
                        sqlstr_add('\n\t\t"'..at1_res[i].COLUMN_NAME..'" '..at1_res[i].COLUMN_TYPE)     -- (beginn of column definition) column_name, column_datatype
                        if at1_res[i].COLUMN_DEFAULT~=null then
                                sqlstr_add(' DEFAULT '..at1_res[i].COLUMN_DEFAULT)                                              -- default
                        end
                        if at1_res[i].COLUMN_IDENTITY~=null then
                                sqlstr_add(' IDENTITY')                                                                                                         -- identity
                        end
                        if not at1_res[i].COLUMN_IS_NULLABLE then                                                                       -- not null
                                sqlstr_add(' NOT NULL')
                        end
                        if at1_res[i].COLUMN_COMMENT~=null then
                                sqlstr_add([[ COMMENT IS ']]..string.gsub(at1_res[i].COLUMN_COMMENT, [[']], [['']])..[[']])                                   -- column comment
                        end
                        if at1_res[i].COLUMN_IS_DISTRIBUTION_KEY == true then
                                table.insert(distr, '"'..at1_res[i].COLUMN_NAME..'"')
                        end
                end --for
                
                if #distr > 0 then
                	sqlstr_add(',\n\t\tDISTRIBUTE BY '..table.concat(distr, ', '))
                end

                if (version_short ~= ('6.0')) and (version_short ~= ('5.0')) then                                      --partition by
                        at2_success, at2_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_COLUMNS WHERE COLUMN_SCHEMA=:s AND COLUMN_TABLE=:t AND COLUMN_PARTITION_KEY_ORDINAL_POSITION IS NOT NULL ORDER BY COLUMN_PARTITION_KEY_ORDINAL_POSITION]], {s=schema_name, t=tbl_name})
                        if not at2_success then
                                error('Error at at2 -- probably table not found')
                        elseif #at2_res > 0 then

							
                                for p=1,#at2_res do
                                        table.insert(part, '"'..at2_res[p].COLUMN_NAME..'"')
                                end
                        end
                        
                        if #part > 0 then
                        	sqlstr_add(', \n\t\tPARTITION BY '..table.concat(part, ', '))
                        end

                end
                sqlstr_add(' )')
                if tbl_comment ~= null then                                                                                                             -- table comment
                        sqlstr_add('\n\tCOMMENT IS \''..tbl_comment..'\'')
                end
                sqlstr_add(';\n')
                sqlstr_lf()
                sqlstr_commit()
        end
end

function add_schemas_constraint_to_DDL(schema_name)     --ADD THE SCHEMA'S CONSTRAINTS--------------------------------------------------------------------------------------------
        sqlstr_flush()
--      ac1_success, ac1_res = pquery([[SELECT * FROM EXA_DBA_CONSTRAINT_COLUMNS WHERE CONSTRAINT_SCHEMA=:s AND (CONSTRAINT_TYPE='PRIMARY KEY' OR CONSTRAINT_TYPE='FOREIGN KEY') ORDER BY CONSTRAINT_TYPE desc, COLUMN_NAME]], {s=schema_name})
        ac1_success, ac1_res = pquery([[/*snapshot execution*/with sel1 as (
        select COL.constraint_schema, COL.constraint_table, COL.constraint_type, COL.constraint_name, COL.column_name, AC.constraint_enabled, COL.REFERENCED_SCHEMA, COL.REFERENCED_TABLE, COL.REFERENCED_COLUMN
        from EXA_DBA_constraints AC
        join EXA_DBA_constraint_columns COL
        on AC.constraint_name=COL.constraint_name and AC.CONSTRAINT_SCHEMA = COL.CONSTRAINT_SCHEMA and AC.CONSTRAINT_TABLE = COL.CONSTRAINT_TABLE)
select constraint_schema, constraint_table, constraint_type, constraint_name, constraint_enabled, REFERENCED_TABLE, group_concat(column_name separator '","') column_names, group_concat(REFERENCED_COLUMN separator '","') REFERENCED_COLUMNS
from sel1  where constraint_schema=:s AND (REFERENCED_SCHEMA=:s or REFERENCED_SCHEMA is null) AND (CONSTRAINT_TYPE='PRIMARY KEY' OR CONSTRAINT_TYPE='FOREIGN KEY')
group by  constraint_schema, constraint_table, constraint_type, constraint_name, constraint_enabled, REFERENCED_TABLE, REFERENCED_SCHEMA
order by constraint_type desc, constraint_table]], {s=schema_name})
        if not ac1_success then
                error('Error in ac1')
        else
                for i=1,(#ac1_res) do
                        if ac1_res[i].CONSTRAINT_TYPE=='PRIMARY KEY' then
                                sqlstr_add('\tALTER TABLE "'..ac1_res[i].CONSTRAINT_SCHEMA..'"."'..ac1_res[i].CONSTRAINT_TABLE..'"\n\t\tADD CONSTRAINT "'..ac1_res[i].CONSTRAINT_NAME..'"\n\t\t '..ac1_res[i].CONSTRAINT_TYPE..' ("'..ac1_res[i].COLUMN_NAMES..'");\n')
                                sqlstr_lf()
                        elseif ac1_res[i].CONSTRAINT_TYPE=='FOREIGN KEY' then
                                sqlstr_add('\tALTER TABLE "'..ac1_res[i].CONSTRAINT_SCHEMA..'"."'..ac1_res[i].CONSTRAINT_TABLE..'"\n\t\tADD CONSTRAINT "'..ac1_res[i].CONSTRAINT_NAME..'"\n\t\t '..ac1_res[i].CONSTRAINT_TYPE..' ("'..ac1_res[i].COLUMN_NAMES..'")\n\t\t\tREFERENCES "'..ac1_res[i].REFERENCED_TABLE..'"("'..ac1_res[i].REFERENCED_COLUMNS..'");\n')
                                sqlstr_lf()
                        end
                end -- for
                sqlstr_commit()
        end -- else

end -- function

function add_all_constraints_to_DDL(only_cross_schema)   --ADD ALL CONSTRAINTS--------------------------------------------------------------------------------------------
        sqlstr_flush()
--      aac1_success, aac1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_CONSTRAINT_COLUMNS WHERE (CONSTRAINT_TYPE='PRIMARY KEY' OR CONSTRAINT_TYPE='FOREIGN KEY') ORDER BY CONSTRAINT_TYPE desc, CONSTRAINT_SCHEMA, COLUMN_NAME]])
        aac1_success, aac1_res = pquery([[/*snapshot execution*/with sel1 as (
        select COL.constraint_schema, COL.constraint_table, COL.constraint_type, COL.constraint_name, COL.column_name, AC.constraint_enabled, COL.REFERENCED_SCHEMA,  COL.REFERENCED_TABLE, COL.REFERENCED_COLUMN
        from EXA_DBA_constraints AC
        join EXA_DBA_constraint_columns COL
        on AC.constraint_name=COL.constraint_name and AC.CONSTRAINT_SCHEMA = COL.CONSTRAINT_SCHEMA and AC.CONSTRAINT_TABLE = COL.CONSTRAINT_TABLE)
select constraint_schema, constraint_table, constraint_type, constraint_name, constraint_enabled, REFERENCED_TABLE, REFERENCED_SCHEMA, group_concat(column_name separator '","') column_names, group_concat(REFERENCED_COLUMN separator '","') REFERENCED_COLUMNS
from sel1  where (CONSTRAINT_TYPE='PRIMARY KEY' OR CONSTRAINT_TYPE='FOREIGN KEY')
and ((constraint_schema <> REFERENCED_SCHEMA and :only_cs) or not :only_cs)
group by  constraint_schema, constraint_table, constraint_type, constraint_name, constraint_enabled, REFERENCED_TABLE, REFERENCED_SCHEMA
order by constraint_type desc,constraint_schema, constraint_table]], {only_cs=only_cross_schema})

        if not aac1_success then
                error('Error in aac1')
        else
                                sqlstr_add('-- ALL CONSTRAINTS ---------------------------------------------------------------------------------\n')
                                sqlstr_lf()
                sqlstr_commit()
                for i=1,(#aac1_res) do
                        if aac1_res[i].CONSTRAINT_TYPE=='PRIMARY KEY' then
                                sqlstr_add('\tALTER TABLE "'..aac1_res[i].CONSTRAINT_SCHEMA..'"."'..aac1_res[i].CONSTRAINT_TABLE..'"\n\t\tADD CONSTRAINT "'..aac1_res[i].CONSTRAINT_NAME..'"\n\t\t '..aac1_res[i].CONSTRAINT_TYPE..' ("'..aac1_res[i].COLUMN_NAMES..'");\n')
                                sqlstr_lf()
                sqlstr_commit()
                        elseif aac1_res[i].CONSTRAINT_TYPE=='FOREIGN KEY' then
                                sqlstr_add('\tALTER TABLE "'..aac1_res[i].CONSTRAINT_SCHEMA..'"."'..aac1_res[i].CONSTRAINT_TABLE..'"\n\t\tADD CONSTRAINT "'..aac1_res[i].CONSTRAINT_NAME..'"\n\t\t '..aac1_res[i].CONSTRAINT_TYPE..' ("'..aac1_res[i].COLUMN_NAMES..'")\n\t\t\tREFERENCES "'..aac1_res[i].REFERENCED_SCHEMA..'"."'..aac1_res[i].REFERENCED_TABLE..'"("'..aac1_res[i].REFERENCED_COLUMNS..'");\n')
                                sqlstr_lf()
                sqlstr_commit()
                        end
                end -- for
                sqlstr_commit()
        end -- else
end -- function

function add_function_to_DDL(function_text)                             --ADD FUNCTION-------------------------------------------------------------------------------------------
        sqlstr_flush()
        sqlstr_add('--/ \n'..function_text..'\n')
        sqlstr_lf()
        sqlstr_commit()
end

function add_script_to_DDL(schema_name, script_name)                            --ADD SCRIPT-------------------------------------------------------------------------------------------
        sqlstr_flush()
        as1_success, as1_res = pquery([[/*snapshot execution*/SELECT SCRIPT_SCHEMA, SCRIPT_TEXT FROM EXA_DBA_SCRIPTS WHERE SCRIPT_SCHEMA=:ss AND SCRIPT_NAME=:sn]], {ss=schema_name, sn=script_name})
                if not as1_success then
                        error('Error at as1')
                end
        sqlstr_lf()
        sqlstr_add('-- BEGIN OF SCRIPT: '..schema_name..'.'..script_name..' ======================================================================================================\n')
        sqlstr_commit()
        sqlstr_add('\nOPEN SCHEMA \"'..schema_name..'\";')    --Open schema to create the script
        sqlstr_commit()
        sqlstr_add('\n--/\n'..as1_res[1].SCRIPT_TEXT..'\n/')
        sqlstr_commit()
        sqlstr_add('\nCLOSE SCHEMA;')
        sqlstr_commit()
        sqlstr_add('\n-- END OF SCRIPT: '..schema_name..'.'..script_name..' ======================================================================================================\n')
        sqlstr_lf()
        sqlstr_commit()
end

function add_schema_to_DDL(schemaname, schema_comment)          --ADD SCHEMA-------------------------------------------------------------------------------------------
        sqlstr_flush()
        sqlstr_add('--SCHEMA: '..schemaname..' -------------------------------------------------------------------------------------------\n')
        sqlstr_lf()
        sqlstr_commit()
        sqlstr_add([[CREATE SCHEMA "]]..schemaname..'\";\n')
        if schema_comment ~= null then
                sqlstr_add('COMMENT ON SCHEMA \"'..schemaname..'\" IS \''..schema_comment..'\';\n')
        end

        if (version_short ~= ('6.0')) and (version_short ~= ('5.0')) then              -- Add schema size limit
                ads1_suc, ads1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_OBJECT_SIZES WHERE OBJECT_TYPE = 'SCHEMA' AND OBJECT_NAME = :s]],{s=schemaname})

                if not (ads1_suc) then
                        error('Error checking schema size limit')
                else

                        if ads1_res[1].RAW_OBJECT_SIZE_LIMIT ~= null then
                                sqlstr_add('\n\tALTER SCHEMA "'..ads1_res[1].OBJECT_NAME..'" SET RAW_SIZE_LIMIT='..ads1_res[1].RAW_OBJECT_SIZE_LIMIT..';\n')
                        end
                end
        end
         --if
        sqlstr_lf()
        sqlstr_commit()
end

function write_table(p_type_in, p_txt_in)
        summary[#summary+1] = {p_txt_in}

        if store_in_table == true then
        idx = idx + 1
        suc, res = pquery([[INSERT INTO DB_HISTORY.DATABASE_DDL VALUES (:ct, :rn, :type, :txt)]]
                      ,{ct = t[1].CT, rn = idx, type = p_type_in, txt=p_txt_in})
                if (suc) then
                else
                        output(string.len(p_txt_in))
                        output(string.sub(p_txt_in, 1, 150000))
                        errtext = "Type is :"..type(summary[1]).."Error in script!!: "..res.error_message
                        error(errtext)
                end

        end
        ddl_flush()
end

function add_all_priority_groups()                              -- ADD PRIORITY GROUPS (AFTER VERSION 6.1)
        aapg1_suc, aapg1_res = pquery([[/*snapshot execution*/select * from exa_priority_groups where PRIORITY_GROUP_NAME NOT IN ('HIGH', 'MEDIUM', 'LOW')]])

        if not (aapg1_suc) then
                error('ERROR CREATING PRIORITY GROUPS')
        end

        sqlstr_add('-- PRIORITY GROUPS --------------------------------------------------------------------\n')
        sqlstr_lf()
        if (#aapg1_res) == 0 then
                sqlstr_add('\t--no Priority Groups\n')
        end
        for i=1,(#aapg1_res) do
                sqlstr_add('\tCREATE PRIORITY GROUP \"'..aapg1_res[i].PRIORITY_GROUP_NAME..'\" WITH WEIGHT = '..aapg1_res[i].PRIORITY_GROUP_WEIGHT..';\n\t\t')
                if (aapg1_res[i].PRIORITY_GROUP_COMMENT ~= NULL) then

                        sqlstr_add('\n\t\tCOMMENT ON PRIORITY GROUP "'..aapg1_res[i].PRIORITY_GROUP_NAME..'" IS \''..aapg1_res[i].PRIORITY_GROUP_COMMENT..'\'; \n\t\t ')
                else
                        sqlstr_add('\n\n')
                end
                sqlstr_commit()
        end
end

function add_system_parameters()                                --ADD SYSTEM PARAMETERS
        asp1_suc, asp1_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_PARAMETERS WHERE SYSTEM_VALUE IS NOT NULL AND PARAMETER_NAME != 'NICE']])

        if not (asp1_suc) then
                error('Error retrieving system parameters')
        else
                sqlstr_add('--SYSTEM PARAMETERS --------------------------------------------------------------------\n')
                for i=1, #asp1_res do
                        -- FOR NUMBERS
                        if asp1_res[i].PARAMETER_NAME == ('NLS_FIRST_DAY_OF_WEEK') or
                           asp1_res[i].PARAMETER_NAME == ('QUERY_TIMEOUT') or
                           asp1_res[i].PARAMETER_NAME == ('IDLE_TIMEOUT') or
                           asp1_res[i].PARAMETER_NAME == ('ST_MAX_DECIMAL_DIGITS') then
                                sqlstr_add('ALTER SYSTEM SET '..asp1_res[i].PARAMETER_NAME..' = '..asp1_res[i].SYSTEM_VALUE..';\n')
                        -- FOR DOUBLE QUOTES
                        elseif asp1_res[i].PARAMETER_NAME == ('DEFAULT_PRIORITY_GROUP') or
                               asp1_res[i].PARAMETER_NAME == ('DEFAULT_CONSUMER_GROUP') then
                                sqlstr_add('ALTER SYSTEM SET '..asp1_res[i].PARAMETER_NAME..' = "'..asp1_res[i].SYSTEM_VALUE..'";\n')
                        -- FOR SINGLE QUOTES
                        else
                                sqlstr_add('ALTER SYSTEM SET '..asp1_res[i].PARAMETER_NAME..' = \''..asp1_res[i].SYSTEM_VALUE..'\';\n')
                        end
                end
        end

        asp2_suc, asp2_res = pquery([[/*snapshot execution*/SELECT * FROM EXA_PARAMETERS WHERE SESSION_VALUE IS NOT NULL AND PARAMETER_NAME NOT IN ('QUERY_TIMEOUT', 'DEFAULT_PRIORITY_GROUP','DEFAULT_CONSUMER_GROUP','PASSWORD_EXPIRY_POLICY','PASSWORD_SECURITY_POLICY','TEMP_DB_RAM_LIMIT','USER_TEMP_DB_RAM_LIMIT')]])

        if not (asp2_suc) then
                error('Error retrieving session parameters')
        else
                sqlstr_add('--SESSION PARAMETERS --------------------------------------------------------------------\n')
                for i=1, #asp2_res do
                        if asp2_res[i].PARAMETER_NAME == ('NLS_FIRST_DAY_OF_WEEK') or
                           asp2_res[i].PARAMETER_NAME == ('IDLE_TIMEOUT') or
                           asp2_res[i].PARAMETER_NAME == ('ST_MAX_DECIMAL_DIGITS') then
                                sqlstr_add('ALTER SESSION SET '..asp2_res[i].PARAMETER_NAME..' = '..asp2_res[i].SESSION_VALUE..';\n')
                        elseif asp2_res[i].PARAMETER_NAME == 'DEFAULT_PRIORITY_GROUP' then
                                sqlstr_add('ALTER SESSION SET '..asp2_res[i].PARAMETER_NAME..' = "'..asp2_res[i].SESSION_VALUE..'";\n')
                        else
                                sqlstr_add('ALTER SESSION SET '..asp2_res[i].PARAMETER_NAME..' = \''..asp2_res[i].SESSION_VALUE..'\';\n')
                        end
                end
        end
        sqlstr_commit()
end

function add_all_virtual_schemas()              -- ADD ALL VIRTUAL SCHEMAS -----------------------------------------------------------------------------------------
		if (version_short >='8.0') then
			avs1_success, avs1_res = pquery([[/*snapshot execution*/select
'CREATE VIRTUAL SCHEMA "' || s.SCHEMA_NAME || '" USING "' || ADAPTER_SCRIPT_SCHEMA || '"."' || ADAPTER_SCRIPT_NAME || '"
WITH
' || GROUP_CONCAT(PROPERTY_NAME || ' = ''' || PROPERTY_VALUE || '''' ORDER BY PROPERTY_NAME SEPARATOR '
') || ';
' AS TEXT
from
EXA_DBA_VIRTUAL_SCHEMAS s
join
EXA_DBA_VIRTUAL_SCHEMA_PROPERTIES p on s.SCHEMA_NAME=p.SCHEMA_NAME
group by s.schema_name, ADAPTER_SCRIPT_SCHEMA, ADAPTER_SCRIPT_NAME;]])
		else
		
        	avs1_success, avs1_res = pquery([[/*snapshot execution*/select
'CREATE VIRTUAL SCHEMA "' || s.SCHEMA_NAME || '" USING ' || ADAPTER_SCRIPT || '
WITH
' || GROUP_CONCAT(PROPERTY_NAME || ' = ''' || PROPERTY_VALUE || '''' ORDER BY PROPERTY_NAME SEPARATOR '
') || ';
' AS TEXT
from
EXA_DBA_VIRTUAL_SCHEMAS s
join
EXA_DBA_VIRTUAL_SCHEMA_PROPERTIES p on s.SCHEMA_NAME=p.SCHEMA_NAME
group by s.schema_name, adapter_script;]])

end
        output(#avs1_res)
        if not avs1_success then
                error('Error Creating virtual Schemas')
        end
        if (#avs1_res) >= 1 then -- if more than system roles 'public' and 'dba'
--              sqlstr_flush()
                sqlstr_add('-- VIRTUAL SCHEMAS --------------------------------------------------------------------\n')
                sqlstr_commit()
                sqlstr_lf()
                for i=1, #avs1_res do
                        sqlstr_add('\t'..avs1_res[i].TEXT..'\n\n')
                end
                sqlstr_commit()
                sqlstr_lf()
        else
                        sqlstr_add('-- VIRTUAL SCHEMAS --------------------------------------------------------------------\n')
                        sqlstr_lf()
                        sqlstr_add('\t-- no virtual schemas defined.\n')
                        sqlstr_lf()
                        sqlstr_commit()
        end
end

function add_all_consumer_groups()                              -- ADD CONSUMER GROUPS (AFTER VERSION 7.0)
        aapg1_suc, aapg1_res = pquery([[/*snapshot execution*/select * from exa_consumer_groups where CONSUMER_GROUP_NAME NOT IN ('HIGH', 'MEDIUM', 'LOW', 'SYS_CONSUMER_GROUP')]])
        if not (aapg1_suc) then
                error('ERROR CREATING CONSUMER GROUPS')
        end

        sqlstr_add('-- CONSUMER GROUPS --------------------------------------------------------------------\n')
        sqlstr_lf() 
        if (#aapg1_res) == 0 then
                sqlstr_add('\t--no Consumer Groups\n')
        end
        for i=1,(#aapg1_res) do
                -- mandatory
                sql_cons_group = '\tCREATE CONSUMER GROUP \"'..aapg1_res[i].CONSUMER_GROUP_NAME..'\" WITH PRECEDENCE = '..aapg1_res[i].PRECEDENCE..' ,CPU_WEIGHT = '..aapg1_res[i].CPU_WEIGHT
                                              
                -- optional
                if (aapg1_res[i].GROUP_TEMP_DB_RAM_LIMIT ~= NULL) then
                    sql_cons_group = sql_cons_group..' ,GROUP_TEMP_DB_RAM_LIMIT = '..aapg1_res[i].GROUP_TEMP_DB_RAM_LIMIT
                end
                if (aapg1_res[i].USER_TEMP_DB_RAM_LIMIT ~= NULL) then
                    sql_cons_group = sql_cons_group..' ,USER_TEMP_DB_RAM_LIMIT = '..aapg1_res[i].USER_TEMP_DB_RAM_LIMIT
                end
                if (aapg1_res[i].SESSION_TEMP_DB_RAM_LIMIT ~= NULL) then
                    sql_cons_group = sql_cons_group..' ,SESSION_TEMP_DB_RAM_LIMIT = '..aapg1_res[i].SESSION_TEMP_DB_RAM_LIMIT
                end
                
                -- new in V7.1
                if (version_short >= ('7.1')) then
                   if (aapg1_res[i].IDLE_TIMEOUT ~= NULL) then
                       sql_cons_group = sql_cons_group..' ,IDLE_TIMEOUT = '..aapg1_res[i].IDLE_TIMEOUT
                   end
                   if (aapg1_res[i].QUERY_TIMEOUT ~= NULL) then
                       sql_cons_group = sql_cons_group..' ,QUERY_TIMEOUT = '..aapg1_res[i].QUERY_TIMEOUT
                   end
                end
                
                sql_cons_group = sql_cons_group..'; \n\t\t'
                sqlstr_add(sql_cons_group)
                
                if (aapg1_res[i].CONSUMER_GROUP_COMMENT ~= NULL) then
                        sqlstr_add('\n\t\tCOMMENT ON CONSUMER GROUP "'..aapg1_res[i].CONSUMER_GROUP_NAME..'" IS \''..aapg1_res[i].CONSUMER_GROUP_COMMENT..'\'; \n\t\t ')
                else
                        sqlstr_add('\n\n')
                end
                sqlstr_commit()
         end
end


-- MAIN --------------------------------------------------------------------------------------------------------------------------------------------
-- Check if the user has SELECT ANY DICTIONARY privilege:
        privsuc, privcheck = pquery([[/*snapshot execution*/SELECT * FROM EXA_DBA_USERS LIMIT 1]])

        if not (privsuc) then
                error('The User does not have SELECT ANY DICTIONARY privilege')
        end

check_version()
-- Prepare Output Table if requested
if store_in_table == true then

        if version_short ~= '5.0' then

                cschemsucc,cschemres = pquery([[CREATE SCHEMA IF NOT EXISTS "DB_HISTORY";]])
                if (cschemsucc) then

                        ctabsuc, ctabres = pquery ([[CREATE TABLE IF NOT EXISTS "DB_HISTORY"."DATABASE_DDL" (BACKUP_TIME TIMESTAMP, rn decimal(5), type varchar(20), DDL varchar(2000000));]])
                        if (ctabsuc) then
                        query ([[COMMIT]])
                else
                                error('error in creating DDL Table')
                        end
                else
                        error('error in create DDL schema')
                end
        else
                checkschemsucc,checkschemres = pquery([[/*snapshot execution*/SELECT SCHEMA_NAME FROM EXA_SCHEMAS WHERE SCHEMA_NAME = 'DB_HISTORY']])

                if not (checkschemsucc) then
                        error('Error checking for DB_HISTORY schema')
                else
                        if (#checkschemres) > 0 then
                                cschemsucc,cschemres= pquery([[OPEN SCHEMA "DB_HISTORY"]])
                        else
                                cschemsucc,cschemres = pquery([[CREATE SCHEMA "DB_HISTORY";]])
                        end
                end

                if (cschemsucc) then
                        ctabchecksuc, ctabcheckres = pquery([[/*snapshot execution*/SELECT TABLE_NAME FROM EXA_DBA_TABLES WHERE TABLE_SCHEMA='DB_HISTORY' AND TABLE_NAME='DATABASE_DDL';]])

                        if not (ctabchecksuc) then
                                error('Error checking for Database_ddl table')
                        else
                                if (#ctabcheckres) == 0 then
                                        ctabsuc, ctabres = pquery ([[CREATE TABLE "DB_HISTORY"."DATABASE_DDL" (BACKUP_TIME TIMESTAMP, rn decimal(5), type varchar(20), DDL varchar(2000000));]])

                                        if (ctabsuc) then
                                        query([[COMMIT]])
                                else
                                                error('error in creating DDL Table')
                                        end

                                end
                        end

                else
                        error('error in create DDL schema')
                end
        end
end

t=query([[/*snapshot execution*/SELECT CURRENT_USER AS CU,CURRENT_TIMESTAMP AS CT]])

constraints_separately = true
return_in_one_row = true

ddl = ''
summary = {{'START'}}
sqlstr =[[]]
sqlstr_add('\n--DDL created by user '..t[1].CU..' at '..t[1].CT..'\n\n')
sqlstr_commit()
sqlstr_flush()

--Check Versioning and insert into string
check_version()

sqlstr_add([[--Database Version: ]]..version_full..'\n')
if version_short == '5.0' then
        sqlstr_add([[--WARNING: Version 5 is not supported]].. '\n')
end

-- ENABLE PROFILING

sqlstr_add([[ALTER SESSION SET PROFILE='ON';]]..'\n')
sqlstr_add([[SET DEFINE OFF;]]..'\n')
sqlstr_commit()
idx = 0
write_table('HEADER',ddl)

add_system_parameters()
write_table('SYSTEM PARAMETERS', ddl)
                                                                                -- roles, users
if add_user_structure then
        if (version_short == ('6.1') or version_short == ('6.2')) then
                add_all_priority_groups()
                write_table('PRIORTY GROUPS', ddl)
        elseif (version_short == ('6.0') or version_short == ('5.0')) then
              a=1
        elseif (version_short >= ('7.0')) then
              add_all_consumer_groups()
              write_table('CONSUMER GROUPS',ddl)
        else
              a=1
        end
        add_all_roles()
        write_table('ROLES',ddl)
        add_all_users()
        write_table('USERS',ddl)
end

                                                                                -- schemas
if version_short == '5.0' then
        m1_success, m1_res = pquery([[select OBJECT_NAME, OBJECT_COMMENT from EXA_DBA_OBJECTS WHERE OBJECT_TYPE = 'SCHEMA' ORDER BY OBJECT_NAME]])
else

        m1_success, m1_res = pquery([[/*snapshot execution*/select OBJECT_NAME, OBJECT_COMMENT from EXA_DBA_OBJECTS WHERE OBJECT_TYPE = 'SCHEMA' AND OBJECT_IS_VIRTUAL IS FALSE ORDER BY OBJECT_NAME]])
end
if not m1_success then
        error('Error at m1')
else
        for i=1,(#m1_res) do -- iterate through all schemas
                add_schema_to_DDL(m1_res[i].OBJECT_NAME, m1_res[i].OBJECT_COMMENT)

                m2_success, m2_res = pquery([[/*snapshot execution*/select table_schema,table_name,table_comment from EXA_DBA_TABLES WHERE TABLE_SCHEMA=:s ORDER BY TABLE_NAME]], {s = m1_res[i].OBJECT_NAME})
                if not m2_success then
                        error('Error at m2')
                else
                        for j=1,(#m2_res) do -- iterate through all tables of the current schema
                                add_table_to_DDL(m2_res[j].TABLE_SCHEMA,m2_res[j].TABLE_NAME, m2_res[j].TABLE_COMMENT)
                        end
                        if not constraints_separately then -- outline constraints within schema block
                                                add_schemas_constraint_to_DDL(m1_res[i].OBJECT_NAME)
                        end -- if
                end     -- else (tables)
                                                                        -- add all functions to the schema
                m21_success, m21_res=pquery([[/*snapshot execution*/SELECT
		FUNCTION_NAME
		, 'CREATE ' || rtrim(FUNCTION_TEXT, '/' || CHR(13) || CHR(10)) || CHR(13) || CHR(10) || '/' AS function_text				 
	FROM
		EXA_DBA_FUNCTIONS
		WHERE FUNCTION_SCHEMA=:s]],{s = m1_res[i].OBJECT_NAME})
                if not m21_success then
                        error('Error at m21')
                else
                        for j=1,(#m21_res) do
                                add_function_to_DDL(m21_res[j].FUNCTION_TEXT)
                        end -- for
                end --else
                                                                -- get all script names of the current schema
                m4_success, m4_res=pquery([[/*snapshot execution*/SELECT SCRIPT_SCHEMA,SCRIPT_NAME FROM EXA_DBA_SCRIPTS WHERE SCRIPT_SCHEMA=:s]],{s = m1_res[i].OBJECT_NAME})
                if not m4_success then
                        error('Error at m3')
                end -- if
                for j=1,(#m4_res) do -- add scripts of the schema
                        add_script_to_DDL(m4_res[j].SCRIPT_SCHEMA,m4_res[j].SCRIPT_NAME)
                end -- for (scripts)

    write_table('SCHEMA', ddl)
    end --for (schemas)

    -- add all views
    add_all_views_to_DDL()
    write_table('VIEWS',ddl)

    -- add all connections
    add_all_connections()
    write_table('CONNECTIONS',ddl)

    --add all virtual schemas
    if version_short ~= '5.0' then
      add_all_virtual_schemas()
      write_table('VIRTUAL SCHEMAS', ddl)
    end

      -- add constraints - all or only cross-schema, based on constraints_separately variable
							
      add_all_constraints_to_DDL(not constraints_separately)
      write_table('CONSTRAINTS',ddl)
	   

        if add_user_structure then
          change_schema_owners()
          write_table('SCHEMA OWNERS',ddl)
        end

        if add_rights then
                add_all_rights()
        write_table('RIGHTS',ddl)
        end

        ddl_endings()
        write_table('FOOTER',ddl)

end -- else

-- ##### Return results
summary[#summary+1] = {'STOP'}

-- Remove nulls from the summary table
summary_new={}
for i=1, #summary do
        if (string.match(summary[i][1], '%a')) then
                summary_new[#summary_new+1] = summary[i][1]
        else

        end
end

summary={{}}
for i=1, #summary_new do
        summary[#summary+1] = {summary_new[i]}
end
table.remove(summary,1)
return summary, "DDL varchar(2000000)"

/

--/
CREATE OR REPLACE LUA SCRIPT exa_toolbox."BACKUP_SYS" (file_location) RETURNS TABLE AS

summary={}

local suc1, res1 = pquery([[select schema_name, object_name from exa_syscat
                                                           where instr(object_name,'EXA_USER_') = 0
                                                             and instr(object_name,'EXA_ALL_') = 0
                                                             and instr(object_name,'AUDIT') = 0
                        ; ]])

if suc1 then
        for i=1, #res1 do
                summary[#summary+1] = {[[export ]]..res1[i].SCHEMA_NAME..[[.]]..res1[i].OBJECT_NAME..[[ into local csv file ']]..file_location..[[]]..res1[i][2]..[[.csv.gz' truncate;]]}
        end
else
        local error_msg = "ERR: ["..res1.error_code.."] "..res1.error_message
        exit(query([[SELECT :error as ERROR FROM DUAL;]], {error=error_msg}))
end

return summary, "DDL varchar(2000000)"

/

--/
CREATE OR REPLACE LUA SCRIPT exa_toolbox."RESTORE_SYS" RETURNS TABLE AS

summary={}

summary[#summary+1] = {[[ALTER SESSION SET PROFILE='on';]]}
summary[#summary+1] = {[[CREATE SCHEMA IF NOT EXISTS SYS_OLD;]]}

local suc1, res1 = pquery([[select schema_name, object_name from exa_syscat
                                                           where instr(object_name,'EXA_USER_') = 0
                                                             and instr(object_name,'EXA_ALL_') = 0
                                                             and instr(object_name,'AUDIT') = 0
                        ; ]])

if suc1 then
        for i=1, #res1 do
                summary[#summary+1] = {[[create or replace table SYS_OLD.]]..res1[i][2]..[[ like ]]..res1[i][1]..[[.]]..res1[i][2]..[[;]]}
                summary[#summary+1] = {[[import into SYS_OLD.]]..res1[i][2]..[[ from local csv file ']]..'&'..[[1/]]..res1[i][2]..[[.csv.gz';]]}
        end
else
        local error_msg = "ERR: ["..res1.error_code.."] "..res1.error_message
        exit(query([[SELECT :error as ERROR FROM DUAL;]], {error=error_msg}))
end

return summary, "DDL varchar(2000000)"

/

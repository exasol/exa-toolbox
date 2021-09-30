--CREATE SCHEMA EXA_TOOLBOX;
--/
CREATE OR REPLACE lua SCRIPT EXA_TOOLBOX.create_or_replace_view_preserve_grants(view_text)
/*
 * This script allows to create or replace a view but keeping the privileges on the view.
 * Technically it 
 * 		first checks all existing privilegdes,
 * 		then recreates the view 
 * 		and then applies the previous priviledged again.
 * 
 * Parameters:
 * view_text: Has to start with 'create or replace view '
 * 
 * Example Procedure Call:
 * EXECUTE SCRIPT EXA_TOOLBOX.create_or_replace_view_preserve_grants('CREATE or replace view s1.v1 as select * from dual') ;
 */
AS 
	tokens = sqlparsing.tokenize(view_text)

    compare_text = 'create or replace view '
    compare_tokens = sqlparsing.tokenize(compare_text)
    for i=1,#compare_tokens do
    	if not (string.lower(tokens[i]) == compare_tokens[i]) then
    		error('view text does not match expected syntax')
    	end
    end
    print(tokens[9])
	 
	suc_privs, res_privs = pquery([[SELECT PRIVILEGE, GRANTEE, OBJECT_SCHEMA, OBJECT_NAME FROM sys.EXA_ALL_OBJ_PRIVS WHERE OBJECT_TYPE = 'VIEW' AND OBJECT_SCHEMA||'.'||OBJECT_NAME = :sv]], {sv=string.upper(tokens[9])})
	print(suc_privs)
	if not suc_privs then 
		error('privilileges could not get determined')
	end
	suc_create, res_create = pquery(view_text)
	if not suc_create then 
		error('create view failed, invalid syntax')
	end

	print(#res_privs)
	for i=1, #res_privs do
		grant_query = [[grant ]]..res_privs[i][1]..[[ on ]]..res_privs[i][3]..[[.]]..res_privs[i][4]..[[ to ]]..res_privs[i][2]
		print(grant_query)
		suc_grant, res_grant = pquery(grant_query)
		if not suc_grant then 
			error('grant failed')
		end
	end
/

--
-- Below you can find testcases
--
--SELECT * FROM sys.EXA_ALL_OBJ_PRIVS WHERE OBJECT_TYPE = 'VIEW' AND OBJECT_SCHEMA||'.'||OBJECT_NAME = upper('s1.v1');
--
--/*
--prepare
--*/
--DROP SCHEMA IF EXISTS s1 CASCADE;
--CREATE SCHEMA S1;
--
--CREATE TABLE S1.T1( x INT);
--CREATE TABLE S1.T2( x INT);
--
--CREATE USER user_foo identified BY foo;
--CREATE USER user_bar identified BY bar;
--
--SELECT view_name FROM exa_all_views;
--
--CREATE OR REPLACE VIEW S1.V1 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--CREATE OR REPLACE VIEW S1.V2 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--GRANT SELECT ON s1.v1 TO user_foo;
--GRANT SELECT ON s1.v1 TO user_bar;
--GRANT SELECT ON s1.v2 TO user_foo;
--
--SELECT * FROM sys.EXA_ALL_OBJ_PRIVS eaop WHERE OBJECT_SCHEMA = 'S1' AND OBJECT_name = 'V1' AND object_type = 'VIEW';
----2 rows
--SELECT * FROM sys.EXA_ALL_VIEWS eav WHERE view_schema = 'S1' AND view_name = 'V1';
---- 1 row
--
---- test lower case
--CREATE OR REPLACE VIEW S1.V1 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--CREATE OR REPLACE VIEW S1.V2 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--GRANT SELECT ON s1.v1 TO user_foo;
--GRANT SELECT ON s1.v1 TO user_bar;
--GRANT SELECT ON s1.v2 TO user_foo;
--
--EXECUTE SCRIPT EXA_TOOLBOX.create_or_replace_view_preserve_grants('create or replace view s1.v1 as SELECT * FROM s1.t1 where true UNION ALL SELECT * FROM s1.t2 where true');
---- observed: success, expected: success 
--SELECT * FROM sys.EXA_ALL_OBJ_PRIVS eaop WHERE OBJECT_SCHEMA = 'S1' AND OBJECT_name = 'V1' AND object_type = 'VIEW';
----expected 2 observed 2
--SELECT * FROM sys.EXA_ALL_VIEWS eav WHERE view_schema = 'S1' AND view_name = 'V1';
----expected 1 observed 1
--
---- test upper case
--CREATE OR REPLACE VIEW S1.V1 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--CREATE OR REPLACE VIEW S1.V2 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--GRANT SELECT ON s1.v1 TO user_foo;
--GRANT SELECT ON s1.v1 TO user_bar;
--GRANT SELECT ON s1.v2 TO user_foo;
--EXECUTE SCRIPT EXA_TOOLBOX.create_or_replace_view_preserve_grants('CREATE or replace view s1.v1 as select * from dual') ;
---- observed: success, expected: success 
--SELECT * FROM sys.EXA_ALL_OBJ_PRIVS eaop WHERE OBJECT_SCHEMA = 'S1' AND OBJECT_name = 'V1' AND object_type = 'VIEW';
----expected 2 observed 2
--SELECT * FROM sys.EXA_ALL_VIEWS eav WHERE view_schema = 'S1' AND view_name = 'V1';
----expected 1 observed 1
--
---- test quoted names
--CREATE OR REPLACE VIEW S1.V1 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--CREATE OR REPLACE VIEW S1.V2 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--GRANT SELECT ON s1.v1 TO user_foo;
--GRANT SELECT ON s1.v1 TO user_bar;
--GRANT SELECT ON s1.v2 TO user_foo;
--EXECUTE SCRIPT EXA_TOOLBOX.create_or_replace_view_preserve_grants('CREATE or replace view "S1"."v4" as select * from dual') ;
---- observed: success, expected: success 
--SELECT * FROM sys.EXA_ALL_OBJ_PRIVS eaop WHERE OBJECT_SCHEMA = 'S1' AND OBJECT_name = 'V1' AND object_type = 'VIEW';
----expected 2 observed 2
--SELECT * FROM sys.EXA_ALL_VIEWS eav WHERE view_schema = 'S1' AND view_name = 'V1';
----expected 1 observed 1
--
---- test invalid query
--CREATE OR REPLACE VIEW S1.V1 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--CREATE OR REPLACE VIEW S1.V2 AS SELECT * FROM s1.t1 UNION ALL SELECT * FROM s1.t2;
--GRANT SELECT ON s1.v1 TO user_foo;
--GRANT SELECT ON s1.v1 TO user_bar;
--GRANT SELECT ON s1.v2 TO user_foo;
--EXECUTE SCRIPT EXA_TOOLBOX.create_or_replace_view_preserve_grants('CREATE or replace view s1.v1 as select * from foo') ;
---- observed: error, expected: error 
--SELECT * FROM sys.EXA_ALL_OBJ_PRIVS eaop WHERE OBJECT_SCHEMA = 'S1' AND OBJECT_name = 'V1' AND object_type = 'VIEW';
----expected 2 observed 2
--SELECT * FROM sys.EXA_ALL_VIEWS eav WHERE view_schema = 'S1' AND view_name = 'V1';
----expected 1 observed 1
---- so in this case the existing view and privs will not be changed




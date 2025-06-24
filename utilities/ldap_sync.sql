/* 
The below scripts will help you synchronize database users with LDAP users. The script will search for roles that contain 
a distinguished name as a role comment and will then pull the members of this group from LDAP, create the necessary users, 
and grant permissions. When users are removed from the group in LDAP, the users will also have the role revoked from them

For more information, please see the below knowledge base article:
https://exasol.my.site.com/s/article/Synchronization-of-LDAP-Active-Directory-Groups-and-Members-to-Exasol-Database-Users-and-Roles?language=en_US

Version 2.2:
 - Extended the length of the VARCHAR column definitions to be able to query larger AD's

Version 2.1:
 - Re-arranged order of setting ldap parameters and binding based on https://www.python-ldap.org/en/python-ldap-3.3.0/reference/ldap.html

Version 2.0:
Changes in this version:
 - Created HELPER script to help debug problems with AD attributes
 - improved error handling in all Python scripts
 - Added LDAP timeout parameter to 5 seconds
 - Added comments to all scripts
 - Added enhanced error handling to the Lua script
 - Added DEBUG mode to Lua script, where all statements are rolled back at the end
 - Changed logic of SQL to only GRANT or REVOKE when role membership has changed (previously would always do it)
 - Added SQL logic to allow ALTERing a user in case the dn changes, but the username is the same
 - Removed the CASCADE option from DROP USER. The script will display an error in the output that the user cannot be dropped. This is a sign for DBA to take action
 - Changed output of script to display the query text, success/fail, and what the error message is. An error in one of the statements will no longer break the script

*/



--This script will search for the specified attribute on the given distinguished name
--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_TOOLBOX."GET_AD_ATTRIBUTE" ("LDAP_CONNECTION" VARCHAR(20000) UTF8, "SEARCH_STRING" VARCHAR(20000) UTF8, "ATTR" VARCHAR(10000) UTF8) EMITS ("SEARCH_STRING" VARCHAR(20000) UTF8, "ATTR" VARCHAR(10000) UTF8, "VAL" VARCHAR(10000) UTF8) AS
import ldap

def run(ctx):
	# The below information corresponds to the user needed to connect to ldap who can traverse the ldap structure and pull out user attributes.
	# This information should be stored in a CONNECTION object and you must GRANT ACCESS ON <CONNECTION> FOR <SCRIPT> TO <USER>
	# More details: https://docs.exasol.com/database_concepts/udf_scripts/hide_access_keys_passwords.htm
	uri =   exa.get_connection(ctx.LDAP_CONNECTION).address #ldap/AD server
	user = exa.get_connection(ctx.LDAP_CONNECTION).user   #technical user for LDAP
	password = exa.get_connection(ctx.LDAP_CONNECTION).password  #pwd of technical user
	encoding = "utf8"  #may depend on ldap server, try latin1 or cp1252 if you get problems with special characters

	try:
		#Sets a timeout of 5 seconds to connect to LDAP
		ldap.set_option(ldap.OPT_NETWORK_TIMEOUT, 5.0)
		
		#The below lines are only needed when connecting via ldaps
		ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)   # required options for SSL without cert checking
		ldap.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
		
		# Connects to LDAP
		ldapClient = ldap.initialize(uri)
		
		#Authenticates with user
		ldapClient.bind_s(user, password)
	
		results = ldapClient.search_s(ctx.SEARCH_STRING, ldap.SCOPE_BASE)
	
		# Emits the results of the specified attributes
		for result in results:
			result_dn = result[0]
			result_attrs = result[1]

			if ctx.ATTR in result_attrs:
				for v in result_attrs[ctx.ATTR]:
					ctx.emit(ctx.SEARCH_STRING, ctx.ATTR, v.decode(encoding))

	except ldap.NO_SUCH_OBJECT:
		ctx.emit(ctx.SEARCH_STRING, ctx.ATTR, 'No such object')
	else:
		ldapClient.unbind_s()

/


-- This script will help you explore ldap attributes. This is helpful when you do not know which attributes contain the role members or the username
-- To find out which attributes contain the group members, you can run this: select EXA_TOOLBOX.LDAP_HELPER('LDAP_SERVER', ROLE_COMMENT) from exa_Dba_roles where role_name = <role name>
-- To find out which attributes contain the username, you can run this: select EXA_TOOLBOX.LDAP_HELPER('LDAP_SERVER', user_name) from exa_dba_connections WHERE connection_name = 'LDAP_SERVER'; 
-- For other purposes, you can run the script using the LDAP connection you created and the distinguished name of the object you want to investigate: SELECT EXA_TOOLBOX.LDAP_HELPER(<LDAP connection>,<distinguished name>);
--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_TOOLBOX."LDAP_HELPER" ("LDAP_CONNECTION" VARCHAR(20000) UTF8, "SEARCH_STRING" VARCHAR(20000) UTF8) EMITS ("SEARCH_STRING" VARCHAR(20000) UTF8, "ATTR" VARCHAR(10000) UTF8, "VAL" VARCHAR(10000) UTF8) AS


import ldap

def run(ctx):
	# The below information corresponds to the user needed to connect to ldap who can traverse the ldap structure and pull out user attributes.
	# This information should be stored in a CONNECTION object and you must GRANT ACCESS ON <CONNECTION> FOR <SCRIPT> TO <USER>
	# More details: https://docs.exasol.com/database_concepts/udf_scripts/hide_access_keys_passwords.htm
	uri =   exa.get_connection(ctx.LDAP_CONNECTION).address #ldap/AD server
	user = exa.get_connection(ctx.LDAP_CONNECTION).user   #technical user for LDAP
	password = exa.get_connection(ctx.LDAP_CONNECTION).password  #pwd of technical user
	encoding = "utf8"  #may depend on ldap server, try latin1 or cp1252 if you get problems with special characters

	try:
		#Sets a timeout of 5 seconds to connect to LDAP
		ldap.set_option(ldap.OPT_NETWORK_TIMEOUT, 5.0)
		
		#The below lines are only needed when connecting via ldaps
		ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)   # required options for SSL without cert checking
		ldap.set_option(ldap.OPT_X_TLS_NEWCTX, 0)
		
		# Connects to LDAP
		ldapClient = ldap.initialize(uri)
		
		#Authenticates with user
		ldapClient.bind_s(user, password)
	
		results = ldapClient.search_s(ctx.SEARCH_STRING, ldap.SCOPE_BASE)
	
		# Emits the results of the specified attributes
		for result in results:
			result_dn = result[0]
			result_attrs = result[1]

			for attrs in result_attrs:
				item_str = str(list(x.decode(encoding) for x in result_attrs[attrs]))
				ctx.emit(result_dn, attrs, item_str)

	except ldap.LDAPError as e:
		if e.message['desc'] == 'No such object':
			ctx.emit(ctx.SEARCH_STRING, 'error', 'No such object')
		else:
			raise ldap.LDAPError(e.message['desc'])
		
	finally:
		ldapClient.unbind_s()		

/

-- This script will perform the syncronizations
--/
CREATE OR REPLACE LUA SCRIPT EXA_TOOLBOX."SYNC_AD_GROUPS_TO_DB_ROLES_AND_USERS" (LDAP_CONNECTION, GROUP_ATTRIBUTE, USER_ATTRIBUTE, EXECUTION_MODE) RETURNS TABLE AS

-- GROUP ATTRIBUTE refers to the attribute to search in the group for all of the members. Default is 'member'
-- USER ATTRIBUTE refers to the attribute of the user which contains the username. Default is uid
-- EXECUTION_MODE options: DEBUG or EXECUTE. In debug mode, all queries are rolled back

if GROUP_ATTRIBUTE == NULL then
        GROUP_ATTRIBUTE = 'member'
end

if USER_ATTRIBUTE == NULL then
        USER_ATTRIBUTE = 'uid'
end

if EXECUTION_MODE == NULL then
        debug = false
elseif string.upper(EXECUTION_MODE) == 'EXECUTE' then
        debug = false
elseif string.upper(EXECUTION_MODE) == 'DEBUG' then
        debug = true
else
        error([[Invalid entry for EXECUTION_MODE. Please use 'DEBUG' or 'EXECUTE']])
end


dcl = query([[

WITH 

get_ad_group_members AS (
-- This CTE will get the list of members in LDAP for each role that contains a comment
		SELECT  
		EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, ROLE_COMMENT, :g)
		FROM
		EXA_DBA_ROLES
		where ROLE_NAME NOT IN ('PUBLIC','DBA') AND ROLE_COMMENT IS NOT NULL AND INSTR(LOWER(ROLE_COMMENT),'dc=')>0
		--exclude default EXASOL groups, all other roles MUST be mapped to AD/LDAP groups
		--the mapping to a LDAP role is done via a COMMENT 
	)
, exa_membership as (
-- This CTE gets the list of users who are members of roles from Exasol. This is used to compare the groups between LDAP and EXA
        SELECT R.ROLE_COMMENT, U.DISTINGUISHED_NAME, P.GRANTED_ROLE, P.GRANTEE FROM EXA_DBA_ROLE_PRIVS P
                JOIN EXA_DBA_ROLES R ON R.ROLE_NAME = P.GRANTED_ROLE
                JOIN EXA_DBA_USERS U ON U.USER_NAME = P.GRANTEE
                WHERE R.ROLE_COMMENT IS NOT NULL
                AND U.DISTINGUISHED_NAME IS NOT NULL
                AND GRANTED_ROLE NOT IN ('PUBLIC','DBA')
        )
, alter_users as (
-- This CTE will find all users who do not have a DISTINGUISHED_NAME configured in Exasol, but DOES have a matching username.
-- In these cases, the script will ALTER the user and change the distinguished name instead of re-creating the user
        SELECT 'ALTER USER "' || upper(VAL) || '" IDENTIFIED AT LDAP AS ''' || SEARCH_STRING || ''';' AS DCL_STATEMENT, 1 ORDER_ID, UPPER(val) VAL, search_string
        FROM (
                select EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, VAL, :u) from
			(
				select distinct VAL
				from	
				get_ad_group_members 
				WHERE 
				VAL NOT IN 
				(
					SELECT distinct  DISTINGUISHED_NAME 
					FROM
		 			EXA_DBA_USERS
				)
			)  --get uid attribute as USER_NAME in database
		
		) WHERE upper(VAL) IN (SELECT DISTINCT USER_NAME FROM EXA_DBA_USERS))
, drop_users AS (
-- This CTE will find all users who are no longer a part of any LDAP group and will drop them
-- NOTE: If the user is the owner of any database objects, the DROP will fail and an appropriate error message is displayed in the script output
-- If you want to drop users who are owners, you can amend the query and replace '"; --' with '" CASCADE; --'
		select
		'DROP USER "' || UPPER(USER_NAME) || '"; --' || DISTINGUISHED_NAME  AS DCL_STATEMENT, 5 ORDER_ID
		from
		EXA_DBA_USERS
		WHERE DISTINGUISHED_NAME IS NOT NULL
		AND
		DISTINGUISHED_NAME NOT IN 
		(
			SELECT distinct VAL
			FROM
 			get_ad_group_members 
		)
		AND UPPER(USER_NAME) NOT IN (SELECT VAL FROM ALTER_USERS)
	)

, create_users AS (
-- This CTE will create users who are found to be in an LDAP group, but the distinguished name is not found in Exasol
-- Users who are altered are ignored and not created again
		select
		'CREATE USER "' ||  UPPER(VAL)  || '"  IDENTIFIED AT LDAP AS ''' || SEARCH_STRING ||''';'  AS DCL_STATEMENT,2 ORDER_ID
		from

		(
			select EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, VAL, :u) from
			(
				select distinct VAL
				from	
				get_ad_group_members 
				WHERE 
				VAL NOT IN 
				(
					SELECT distinct  DISTINGUISHED_NAME 
					FROM
		 			EXA_DBA_USERS
				)
			)  --get uid attribute as USER_NAME in database
		
		)WHERE VAL NOT like '%No such object%'
		AND UPPER(VAL) NOT IN (SELECT VAL FROM ALTER_USERS)

	)
,revokes AS (
-- This CTE will only revoke roles from users if they are a part a member of the role in EXA, but are no longer in the group in LDAP
		SELECT 'REVOKE "' || GRANTED_ROLE || '" FROM "' || UPPER(GRANTEE) || '";' AS DCL_STATEMENT, 3 ORDER_ID from exa_membership e
                full outer join get_ad_group_members a on e.role_comment = a.search_string and e.distinguished_name = a.val
                where search_string is null
	)
,all_user_names(DISTINGUISHED_NAME, VAL, USER_NAME)  as (
-- This CTE will get the "user name" attribute for LDAP. The exact attribute may vary
	select EXA_TOOLBOX.GET_AD_ATTRIBUTE(:l, VAL, :u) from
	(
		select distinct VAL
		from	
		get_ad_group_members 
	)

)
, grants AS (
-- This CTE will grant roles to users when it sees an LDAP user who is a role member, but the equivalent database user is not granted the role
        SELECT 'GRANT "' || R.ROLE_NAME ||'" TO "' || UPPER(U.USER_NAME) || '";' AS DCL_STATEMENT, 4 ORDER_ID FROM EXA_MEMBERSHIP e
		FULL OUTER JOIN get_ad_group_members a on e.role_comment = a.search_string and e.distinguished_name = a.val
		full outer join 
		      (SELECT ROLE_NAME, ROLE_COMMENT FROM EXA_DBA_ROLES where ROLE_NAME NOT IN ('PUBLIC','DBA') AND ROLE_COMMENT IS NOT NULL) r
		      on r.role_comment = a.search_string 
		JOIN ALL_USER_NAMES u on u.distinguished_name = a.val
		where e.role_comment is null
		and  u.USER_NAME NOT like '%No such object%'
		
	)

select DCL_STATEMENT, ORDER_ID from alter_users

union all

select * from  create_users

union all

select * from revokes

union all

select * from grants

union all

select * from drop_users

order by ORDER_ID ;

]], {l=LDAP_CONNECTION, u=USER_ATTRIBUTE, g=GROUP_ATTRIBUTE})

summary = {}

if (debug) then
-- in debug mode, all queries are performed to see what an error message may be, but are then rolled back so no changes are committed.
        summary[#summary+1] = {"DEBUG MODE ON - ALL QUERIES ROLLED BACK",null,null}
        for i=1,#dcl do
        
                output(dcl[i].DCL_STATEMENT)
                suc,res = pquery(dcl[i].DCL_STATEMENT)
                
                if (suc) then
                -- query was successful
                        summary[#summary+1] = {dcl[i].DCL_STATEMENT,'TRUE',NULL}
                else
                -- query returned an error message, display the error in the script output
                        summary[#summary+1] = {dcl[i].DCL_STATEMENT,'FALSE',res.error_message}
                end
        end 
        query([[ROLLBACK]])
else
-- Not debug mode, queries can be committed on script completion
        for i=1,#dcl do
                suc,res = pquery(dcl[i].DCL_STATEMENT)
                
                if (suc) then
                --query was successful
                        summary[#summary+1] = {dcl[i].DCL_STATEMENT,'TRUE',NULL}
                else
                --query returned an error message, display the error in the script output
                        summary[#summary+1] = {dcl[i].DCL_STATEMENT,'FALSE',res.error_message}
                end  
        end
end

return summary, ("QUERY_TEXT VARCHAR(200000),SUCCESS BOOLEAN, ERROR_MESSAGE VARCHAR(20000)")

/

create schema if not exists exa_toolbox;

/*
        This script creates DDL statements for recursive dependencies of a view. 
        The DDL are presented as a single-column result-set and are ready for copy/paste into a text editor or SQL-editor for saving.
        
        Originally mentioned in article https://exasol.my.site.com/s/article/How-to-create-DDL-for-Exasol-support?language=en_US
*/

--/
create or replace script exa_toolbox.create_view_ddl(view_schema, view_name) returns table as
/* 
PARAMETERS: 
	-	view_schema: 	location of view (case-sensitive)
	-	view_name: 		name of view (case-sensitive)
*/
local summary = {}
local constraints_separately = true

function print( text )
	summary[1+#summary] = { text }
end

-- 'class' for schema handling
schema = {
	-- list of created schemas
	exists = {},

	-- current open schema
	current = '',

	-- create and/or open schema
	open = function( self, schema_name, schema_is_virtual )
		if null==schema_name or nil==schema_name or ''==schema_name then return self:close(); end

		if (version_major >= 8) then
			adapter_script_expression = [['"' || vs.adapter_script_schema || '"."' || vs.adapter_script_name || '"']]
		else
			adapter_script_expression = [[vs.ADAPTER_SCRIPT]]
		end

		if nil==self.exists[schema_name] then
			if (schema_is_virtual == true) then
				local av2_success, av2_res = pquery([[select
	vs.schema_name
	, ]] .. adapter_script_expression .. [[ as adapter_script -- use the following expression for version 8: '"' || vs.adapter_script_schema || '"."' || vs.adapter_script_name || '"'
	, 'CREATE VIRTUAL SCHEMA "'||vs.schema_name||'"
USING '||local.adapter_script||' WITH
'|| group_concat(p.property_name||' = '''||p.property_value||'''' order by p.property_name separator '
')||'
;' as vs_text
from
    exa_dba_virtual_schemas vs
        join exa_dba_virtual_schema_properties p
        on vs.schema_name=p.schema_name
where
	1=1
	and vs.schema_name = :s
group by
        vs.schema_name
        , local.adapter_script
]],	{s=schema_name})
			if not av2_success then
				error( 'Error at av2: ' .. av2_res.error_message )
			else
				print(av2_res[1].VS_TEXT .. '\n')
			end
			else
				print( 'CREATE SCHEMA ' .. quote(schema_name) .. ';' )
			end
			self.exists[schema_name] = 1
		else
			if self.current ~= schema_name then
				print( 'OPEN SCHEMA ' .. quote(schema_name) .. ';' )
			end
		end
		self.current = schema_name
	end,

	-- close schema
	close = function( self )
		if null==schema_name or nil==schema_name or ''==schema_name then return ; end
		print( 'CLOSE SCHEMA;' )
		self.current = ''
	end,

	-- just make sure the schema exists. Don't open if exists.
	ensure = function( self, schema_name, schema_is_virtual )
		if self.exists[schema_name] then return; end
		self:open( schema_name, schema_is_virtual )
	end
}


-- 'class' for grouping of output
section = {
	current = '',

	go = function( self, name )
		if self.current == name then return; end
		local width = 40

		print( '\n\n\n--' .. string.rep('=', width) .. '--' )
		local pad_left_len = math.floor((width - #name)/2)
		local pad_right_len = width - pad_left_len - #name
		print( '--' .. string.rep(' ', pad_left_len) .. name .. string.rep(' ', pad_right_len) .. '--' )
		print( '--' .. string.rep('=', width) .. '--' )

		self.current = name
	end


}

local sqlstr = {
	data = {},
	append = function( self, str )
		table.insert(self.data, str)
	end,
	flush = function( self )
		self.data = {}
	end,
	commit = function( self )
		print( table.concat( self.data ) )
		self:flush()
	end,
	endl = function( self )
		self.append( '\n' )
	end

}

function ddl_endings()
	sqlstr:flush()
	sqlstr:endl()
	sqlstr:append('\ncommit;')
	sqlstr:commit();
end

-- add definition of a single table to output
function add_table( table_schema, table_name, table_is_virtual )
	if( table_schema == 'SYS' or table_schema == 'EXA_STATISTICS' ) then
		print( '-- SYSTEM TABLE: ' .. table_schema .. '.' .. table_name )
		return
	end

	schema:ensure( table_schema, table_is_virtual )

	if( table_is_virtual == true ) then
		print( '-- VIRTUAL TABLE: "' .. table_schema .. '"."' .. table_name .. '"')
		return
	end

	local at1_success, at1_res = pquery([[
			SELECT * 
			FROM EXA_DBA_COLUMNS
			WHERE COLUMN_SCHEMA=:s 
			  AND COLUMN_TABLE=:t
			ORDER BY COLUMN_ORDINAL_POSITION
		]],
		{s=table_schema, t=table_name}
	)
	if not at1_success then  
		error( 'Error at at1: ' .. at1_res.error_message )
	elseif #at1_res == 0 then
		local user_query = query('select CURRENT_USER as user_name from dual')
		error( 'Error at at1: The current user ' .. quote(user_query[1].USER_NAME) ..
		' has no access to the object ' .. quote(table_schema) .. '.' ..quote(table_name))
	else
		sqlstr:append(
			[[CREATE TABLE ]] ..
			quote(table_schema) ..
			'.' ..
			quote(table_name) ..
			'(\n\t'
		)
		local distr_keys = {}
		local part_keys = {}
		local columns = {}
		local zonemap_add = {}
		local zonemap_remove = {}

		for i=1, #at1_res do
			local col_def = quote(at1_res[i].COLUMN_NAME) .. ' ' .. at1_res[i].COLUMN_TYPE

			if at1_res[i].COLUMN_DEFAULT~=null then
				col_def = col_def .. ' DEFAULT ' .. at1_res[i].COLUMN_DEFAULT
			end

			if at1_res[i].COLUMN_IDENTITY~=null then	
				col_def = col_def .. ' IDENTITY'
			end

			if not at1_res[i].COLUMN_IS_NULLABLE then
				col_def = col_def .. ' NOT NULL'
			end

			table.insert( columns, col_def )

			if at1_res[i].COLUMN_IS_DISTRIBUTION_KEY then
				table.insert(distr_keys, quote(at1_res[i].COLUMN_NAME))
			end

			if at1_res[i].COLUMN_PARTITION_KEY_ORDINAL_POSITION~=null then
				part_keys[at1_res[i].COLUMN_PARTITION_KEY_ORDINAL_POSITION] = quote(at1_res[i].COLUMN_NAME)
			end

			if (version_major >= 8) then
				if (at1_res[i].COLUMN_PARTITION_KEY_ORDINAL_POSITION==null and at1_res[i].COLUMN_IS_ZONEMAPPED) then
					table.insert(zonemap_add, quote(at1_res[i].COLUMN_NAME))
				end

				if (at1_res[i].COLUMN_PARTITION_KEY_ORDINAL_POSITION~=null and not at1_res[i].COLUMN_IS_ZONEMAPPED) then
					table.insert(zonemap_remove, quote(at1_res[i].COLUMN_NAME))
				end
			end
		end --for
		sqlstr:append( table.concat(columns, ',\n\t') )

		if #distr_keys > 0 then
			sqlstr:append( ',\n\tDISTRIBUTE BY\n\t\t' .. table.concat(distr_keys, ',\n\t\t') )
		end

		if #part_keys > 0 then
			sqlstr:append( ',\n\tPARTITION BY\n\t\t' .. table.concat(part_keys, ',\n\t\t') )
		end
		sqlstr:append('\n);')

		for i=1, #zonemap_add do
			sqlstr:append( '\nENFORCE ZONEMAP ON ' .. quote(table_schema) .. '.' .. quote(table_name) .. '('..zonemap_add[i] .. ');')
		end

		for i=1, #zonemap_remove do
			sqlstr:append( '\nDROP ZONEMAP ON ' .. quote(table_schema) .. '.' .. quote(table_name) .. '('..zonemap_remove[i] .. ');')
		end
		sqlstr:commit()
	end
end

-- add definition for a single view to output
function add_view( view_schema, view_name )
	if( view_schema == 'SYS' or view_schema == 'EXA_STATISTICS' ) then
		print( '-- SYSTEM VIEW: ' .. view_schema .. '.' .. view_name )
		return
	end

	av1_res=query([[
		SELECT SCOPE_SCHEMA, "$VIEW_MIGRATION_TEXT"(VIEW_TEXT) VIEW_TEXT
		FROM EXA_DBA_VIEWS
		WHERE view_schema = :s
		  AND view_name = :v
		]], { s=view_schema, v=view_name }
	)
	
	if #av1_res == 0 then
		error( "View " .. view_schema .. '.' .. view_name .. ' not found!')
	end

	schema:ensure( view_schema )
	schema:open( av1_res[1].SCOPE_SCHEMA, false )
	
	print( 'CREATE VIEW ' .. quote(view_schema) .. '.' .. quote(view_name) ..
		av1_res[1].VIEW_TEXT
	)

	if nil == string.match( av1_res[1].VIEW_TEXT, ';%s*$' ) then
		print( ';' )
	end
end


-- add definition of a single function to output
function add_function( function_schema, function_name )
	local m21_success, m21_res=pquery([[
	SELECT
		FUNCTION_NAME
		, 'CREATE ' || rtrim(FUNCTION_TEXT, '/' || CHR(13) || CHR(10)) || CHR(13) || CHR(10) || '/' AS function_text
	FROM
		EXA_DBA_FUNCTIONS
		WHERE FUNCTION_SCHEMA=:s and FUNCTION_NAME = :n
		]], { s = function_schema, n = function_name }
	)


	if not m21_success then
		error('Error at m21: ' .. m21_res.error_message)
	else
		for j=1,(#m21_res) do
			schema:open( function_schema, false )
			print( m21_res[j].FUNCTION_TEXT )
		end -- for
	end --else
end


-- add definition of a single script to output
function add_script( script_schema, script_name )
	local as1_success, as1_res = pquery([[
			SELECT SCRIPT_SCHEMA, SCRIPT_TEXT
			FROM EXA_DBA_SCRIPTS
			WHERE SCRIPT_SCHEMA = :s and SCRIPT_NAME=:n
		]], {s=script_schema, n=script_name}
	)

	if not as1_success or 0==#as1_res then
		error('Error at as1')
	end

	schema:open( as1_res[1].SCRIPT_SCHEMA, false )
	print( as1_res[1].SCRIPT_TEXT .. '\n/' )
end


-- add definition of a single connection to output
function add_connection( connection_name )
	local ac1_success, ac1_res = pquery([[
			SELECT CONNECTION_STRING, USER_NAME
			FROM EXA_DBA_CONNECTIONS
			WHERE CONNECTION_NAME = :cn
		]], {cn=connection_name}
	)

	if not ac1_success or 0==#ac1_res then
		error('Error at ac1')
	end

	print([[CREATE CONNECTION "]] .. connection_name .. [["
TO ']] .. ac1_res[1].CONNECTION_STRING .. [['
USER ']] .. ac1_res[1].USER_NAME .. [['
IDENTIFIED BY '<change me>'
;]] .. '\n' )
end


-- get known dependencies of given view, sorted to create objects in order of dependency
function get_dependencies( view_schema, view_name )
	return query([[with
deps as(
	SELECT
		d.referenced_object_schema
		, d.referenced_object_name
		, d.referenced_object_type
		, o.object_is_virtual
		, max(d.dependency_level) as dep_lvl
		, decode(d.referenced_object_type,
		'TABLE', 10,
		'SCRIPT', 20,
		'FUNCTION', 30,
		'VIEW', 50,
		100
	) as order_expr_1
	, decode(d.referenced_object_type,
		'TABLE', 0,
		'SCRIPT', 0,
		-- other objects by dependency level and schema
		local.dep_lvl
	)  as order_expr_2
	from
		EXA_DBA_DEPENDENCIES_RECURSIVE d
			left join exa_dba_objects o
			on d.referenced_object_type=o.object_type and d.referenced_object_schema=o.root_name and d.referenced_object_name=o.object_name
	where
		d.object_schema = :s
		and d.object_name = :v
	group by
		1,2,3,4
)
, conn_deps as(
	select
		distinct
		cast(null as VARCHAR(128) UTF8) as referenced_object_schema
		, p.property_value as referenced_object_name
		, 'CONNECTION' as referenced_object_type
		, cast(null as boolean) as object_is_virtual
		, cast(null as DECIMAL(18,0)) as dep_lvl
		, 9 as order_expr_1
		, 0 as order_expr_2
	from
		deps d
			join exa_dba_schemas s
			on d.referenced_object_schema=s.schema_name
	            join exa_dba_virtual_schema_properties p
	            on s.schema_name=p.schema_name
	where
		1=1
		and s.schema_is_virtual
	    -- The following list is not exhaustive
	    -- This part could not be 100% reliable by design as VS authors are free to use different names for connection paramters.
	    and p.property_name in ('CONNECTION_NAME', 'EXA_CONNECTION', 'ORA_CONNECTION_NAME')
)
, script_deps as(
	select
		distinct
		s.script_schema as referenced_object_schema
		, s.script_name as referenced_object_name
		, 'SCRIPT' as referenced_object_type
		, cast(null as boolean) as object_is_virtual
		, cast(null as DECIMAL(18,0)) as dep_lvl
		, 10 as order_expr_1
		, 0 as order_expr_2
	from
		deps d
			join exa_dba_virtual_schemas vs
			on d.referenced_object_schema=vs.schema_name
	            join exa_dba_scripts s
	            --on sv.adapter_script=s.script_schema||'.'||s.script_name
	            on vs.ADAPTER_SCRIPT_SCHEMA=s.script_schema
	            and vs.ADAPTER_SCRIPT_NAME=s.script_name
)
select
	*
from
	deps d

union all

select
	*
from
	conn_deps d

union all

select
	*
from
	script_deps d
-- tables first, then scripts
order by order_expr_1,
	-- sort tables and scripts by schema and object_name only.
	order_expr_2 desc,
	referenced_object_schema,
	referenced_object_name
		]], { s = view_schema, v = view_name }
	)
end

function check_version()
        version_suc, version = pquery([[select
	max(case when m.PARAM_NAME = 'databaseProductVersion' then m.PARAM_VALUE end) as version_full
	, to_number(max(case when m.PARAM_NAME = 'databaseMajorVersion' then m.PARAM_VALUE end)) as version_major
	, to_number(max(case when m.PARAM_NAME = 'databaseMinorVersion' then m.PARAM_VALUE end)) as version_minor
from
	EXA_METADATA m]])

        if not (version_suc) then
                error('error determining version')
        else
                version_full = version[1].VERSION_FULL
                version_major = version[1].VERSION_MAJOR
                version_minor = version[1].VERSION_MINOR
        end
end

-- MAIN --------------------------------------------------------------------------------------------------------------------------------------------

-- add header
local t = query([[SELECT CURRENT_USER AS CU,CURRENT_TIMESTAMP AS CT]])
print( '--DDL created by user '..t[1].CU..' at '..t[1].CT )

-- init: make sure the view exists and is valid (including all dependencies)
query( [[describe ::S.::V]], { S = quote(view_schema), V = quote(view_name) } )

check_version()

-- A -- get recursive list of dependencies for view (unique objects, properly presorted)
deps = get_dependencies( view_schema, view_name )


-- A-2 -- for each dependency, get its definition
local level = 99

for num=1, #deps do
	if deps[num].REFERENCED_OBJECT_TYPE == 'TABLE' then
		section:go('table dependencies')
		add_table( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME, deps[num].OBJECT_IS_VIRTUAL )
	elseif deps[num].REFERENCED_OBJECT_TYPE == 'FUNCTION' then
		section:go('function dependencies')
		add_function( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME )
	elseif deps[num].REFERENCED_OBJECT_TYPE == 'SCRIPT' then
		section:go('script dependencies')
		add_script( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME )
	elseif deps[num].REFERENCED_OBJECT_TYPE == 'CONNECTION' then
		section:go('connection dependencies')
		add_connection( deps[num].REFERENCED_OBJECT_NAME )
	elseif deps[num].REFERENCED_OBJECT_TYPE == 'VIEW' then
		section:go('view dependencies')
		if level > deps[num].DEP_LVL then
			print('\n--> level ' .. deps[num].DEP_LVL)
			level = deps[num].DEP_LVL
		end
		add_view( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME )
	else
		print( "Unhandled dependency type: " .. deps[num].REFERENCED_OBJECT_TYPE .. ' -- ' .. deps[num].REFERENCED_OBJECT_NAME )
	end
end

-- B -- now the view / query itself...
print( '-- final query/view:' )
add_view( view_schema, view_name )

-- ##### Return results
return summary, "DDL varchar(2000000)"

/

-- Example:

-- execute script exa_toolbox.create_view_ddl('DUT', 'TRUNK');
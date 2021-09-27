create schema if not exists exa_toolbox;

/*
        This script creates DDL statements for recursive dependencies of a view. 
        The DDL are presented as a single-column result-set and are ready for copy/paste into a text editor or SQL-editor for saving.
        
        Originally mentioned in article https://community.exasol.com/t5/database-features/how-to-create-ddl-for-exasol-support/ta-p/1734
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
	open = function( self, schema_name )
		if null==schema_name or nil==schema_name or ''==schema_name then return self:close(); end

		if nil==self.exists[schema_name] then
			print( 'CREATE SCHEMA ' .. quote(schema_name) .. ';' )
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
	ensure = function( self, schema_name )
		if self.exists[schema_name] then return; end
		self:open( schema_name )
	end
}


-- 'class' for grouping of output
section = {
	current = '',

	go = function( self, name )
		if self.current == name then return; end
		local width = 40

		print( '\n\n\n--' .. string.rep('=', width) .. '--' )
		local pad = string.rep(' ', (width - #name)/2 )
		print( '--' .. pad .. name .. pad .. '--' )
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
function add_table( table_schema, table_name )
	if( table_schema == 'SYS' or table_schema == 'EXA_STATISTICS' ) then
		print( '-- SYSTEM TABLE: ' .. table_schema .. '.' .. table_name )
		return
	end

	schema:ensure( table_schema )
			SELECT * 
			FROM EXA_DBA_COLUMNS
			WHERE COLUMN_SCHEMA=:s 
			  AND COLUMN_TABLE=:t
	local at1_success, at1_res = pquery([[

			ORDER BY COLUMN_ORDINAL_POSITION
		]],
		{s=table_schema, t=table_name}
	)
	if not at1_success then  
		error( 'Error at at1: ' .. at1_res.error_text )
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
		local columns = {}

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
		end --for
		sqlstr:append( table.concat(columns, ',\n\t') )

		if #distr_keys > 0 then	
			sqlstr:append( ',\n\tDISTRIBUTE BY\n\t\t' .. table.concat(distr_keys, ',\n\t\t') )
		end
		sqlstr:append('\n);')
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
	schema:open( av1_res[1].SCOPE_SCHEMA )
	
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
		FUNCTION_NAME,
		FUNCTION_TEXT || case
			when
				substr(
					rtrim(
						translate(
							function_text,
							CHR(10) || CHR(13),
							'  '
						),
						' '
					),
					-1
				) <> '/'
			then
				'
/'
			else
				''
		end function_text
	FROM
		EXA_DBA_FUNCTIONS
		WHERE FUNCTION_SCHEMA=:s and FUNCTION_NAME = :n
		]], { s = function_schema, n = function_name }
	)


	if not m21_success then
		error('Error at m21: ' .. m21_res.error_text)
	else
		for j=1,(#m21_res) do
			schema:open( function_schema )
			print( m21_res[j].FUNCTION_TEXT )
		end -- for
	end --else
end


-- add definition of a single function to output
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

	schema:open( as1_res[1].SCRIPT_SCHEMA )
	print( as1_res[1].SCRIPT_TEXT .. '\n\/' )
end


-- get known dependencies of given view, sorted to create objects in order of dependency
function get_dependencies( view_schema, view_name )
	return query([[
		SELECT referenced_object_schema, referenced_object_name, referenced_object_type, max(dependency_level) as dep_lvl
		from EXA_DBA_DEPENDENCIES_RECURSIVE
		where object_schema = :s
		  and object_name = :v
		group by 1,2,3
		-- tables first, then scripts
		order by decode(referenced_object_type,
				'TABLE', 10,
				'FUNCTION', 20,
				'SCRIPT', 30,
				'VIEW', 40,
				100
			),
			-- sort tables and scripts by schema only.
			decode( referenced_object_type,
				'TABLE', 0,
				'SCRIPT', 0,
				-- other objects by dependency level and schema
				dep_lvl
			) desc,
			referenced_object_schema
		]], { s = view_schema, v = view_name }
	)
end

-- MAIN --------------------------------------------------------------------------------------------------------------------------------------------

-- add header
local t = query([[SELECT CURRENT_USER,CURRENT_TIMESTAMP]])
print( '--DDL created by user '..t[1].CURRENT_USER..' at '..t[1].CURRENT_TIMESTAMP )


-- init: make sure the view exists and is valid (including all dependencies)
query( [[describe ::S.::V]], { S = view_schema, V = view_name } )



-- A -- get recursive list of dependencies for view (unique objects, properly presorted)
deps = get_dependencies( view_schema, view_name )


-- A-2 -- for each dependency, get its definition
local level = 99

for num=1, #deps do
	if deps[num].REFERENCED_OBJECT_TYPE == 'TABLE' then
		section:go('table dependencies')
		add_table( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME )
	else
		if deps[num].REFERENCED_OBJECT_TYPE == 'FUNCTION' then
			section:go('function dependencies')
			add_function( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME )
		else
			if deps[num].REFERENCED_OBJECT_TYPE == 'SCRIPT' then
				section:go('script dependencies')
				add_script( deps[num].REFERENCED_OBJECT_SCHEMA, deps[num].REFERENCED_OBJECT_NAME )
			else
				if deps[num].REFERENCED_OBJECT_TYPE == 'VIEW' then
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
		end
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
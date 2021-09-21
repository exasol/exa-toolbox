create schema if not exists preprocessing;

create or replace lua script preprocessing.exa_pivot() as 

/*
 * returns a table with the start and end index for certain structural keywords
 * e.g. t_sql_structure['SELECT']['START']
 * */
function get_sql_structure(tokens) 
	local t_sql_structure = {}
	local t_sql_keywords = {'WITH', 'SELECT', 'FROM', 'WHERE', 'CONNECT', 'PREFERRING', 'GROUP', 'HAVING', 'QUALIFY', 'ORDER', 'LIMIT'}
	local v_start = -1
	local v_end = -1
	local v_last = #tokens
	
	for i=#t_sql_keywords, 1, -1 do
	
		v_start = sqlparsing.find(tokens, 1, true, true, sqlparsing.iswhitespaceorcomment, t_sql_keywords[i])
		if(v_start == nil) then 
			v_start = -1 --c1
			v_end = -1 --c1
		else 
			v_start = v_start[1] 
			v_end = v_last
		end
		
		t_sql_structure[t_sql_keywords[i]] = {
			['START'] =  v_start, 
			['END'] = v_end
		}
		
		if(v_start > 0) then --c1
			v_last = sqlparsing.find(tokens, v_start -1, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
			if(v_last == nil) then 	
				v_last = -1
			else 
				v_last = v_last[1]
			end
		end	
		
	end	
	return t_sql_structure
end




/*
 * analyses the strucutre of the of a column list, start and end indexes of the whole expression, identifier indexes, table aliases index, column name index, column alias index, expression star and end indexes
 * parameter:
 * 		t_col = {
 * 			['START'] 								= index of the element after which the first element of the select list begings, e.g. "select a, b, c from dual" --> index of "select"
 * 			['END'] 								= the index of the element before the next section begins, "select a, b, c from dual" --> index of the " " before the "from"
 * 		}
 * 
 * returns a table with the following structure
 * t_col[START/END/DISTINCT] 						--> start and end indexes for the whole column list, index of the distinct keyword if it is the first non whitespace/comment element in the column list
 * t_col[i] 										--> one column in the list
 * t_col[i][START/EXPRESSION_END/END/ALIAS] 		--> index where the column starts, where the column expression end, where the whole column ends and the index of the alias
 * t_col[i][IDENTIFIER] 							--> contains a table with all the identifiers used in the column expression
 * t_col[i][IDENTIFIER][j][START/END/TABLE/COLUMN] 	--> start and end indexes of the column identifiers (usually its equal, except for table_alias.* cases), name of the table and column
 * 
 * todo change:
 * t_col[COLUMN][i]
 * t_col[COLUMN][i][IDENTIFIER][j][START/END/TABLE_NAME/COLUMN_NAME]
 * */
function set_col_list(tokens, t_col) 
	local t_col = t_col
	
	local i_start = sqlparsing.find(tokens, t_col['START'] +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
	
	
	t_col['DISTINCT'] = -1
	if(tokens[i_start] == 'DISTINCT') then 
		t_col['DISTINCT'] = i_start
		i_start = sqlparsing.find(tokens, i_start +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
	end
	
	local tmp_cols = get_cst(tokens, i_start, t_col['END'])
	
	--for i=1, #tmp_cols do output(table.concat(tokens, '', tmp_cols[i]['START'], tmp_cols[i]['END'])) end
	
	local tmp_table_column_name = {}
	

	
	for i=1, #tmp_cols do 
		t_col[i] = {
			['START'] = tmp_cols[i]['START'], 
			['EXPRESSION_END'] = tmp_cols[i]['END'],
			['END'] = tmp_cols[i]['END'], 
			['IDENTIFIER'] = {},
			['ALIAS'] = -1
		}	
		local i_prev_index = nil
		
		while i_start <= tmp_cols[i]['END'] do 

			-- * 
			if(i_start == t_col['END'] and tokens[i_start] == '*') then 
			t_col[i]['IDENTIFIER'][#t_col[i]['IDENTIFIER'] +1] = {
					['START'] = i_start, 
					['END'] = i_start,
					['TABLE_NAME'] = '', 
					['COLUMN_NAME'] = '*'
				}
			
			-- table_alias.* or column_name column_alias
			elseif(tmp_cols[i]['END'] - tmp_cols[i]['START'] == 2 and tmp_cols[i]['START'] == i_start) then
				if((sqlparsing.isidentifier(tokens[i_start]) and not sqlparsing.iskeyword(tokens[i_start])) and tokens[i_start +1] == '.' and tokens[i_start +2] == '*') then 
					t_col[i]['IDENTIFIER'][#t_col[i]['IDENTIFIER'] +1] = {
						['START'] = i_start, 
						['END'] = i_start +2,
						['TABLE_NAME'] = unquote(tokens[i_start]), 
						['COLUMN_NAME'] = tokens[i_start +2]
					}
					i_start = i_start +2
				elseif(sqlparsing.isidentifier(tokens[i_start]) and not sqlparsing.iskeyword(tokens[i_start])) then
					tmp_table_column_name = get_table_column_name(tokens[i_start])
					t_col[i]['IDENTIFIER'][#t_col[i]['IDENTIFIER'] +1] = {
						['START'] = i_start, 
						['END'] = i_start,
						['TABLE_NAME'] = tmp_table_column_name['TABLE_NAME'], 
						['COLUMN_NAME'] = tmp_table_column_name['COLUMN_NAME']
					}
				end
				
			-- column_alias
			elseif(tmp_cols[i]['END'] == i_start and tmp_cols[i]['END'] > tmp_cols[i]['START'] and (sqlparsing.isidentifier(tokens[i_start]) and not sqlparsing.iskeyword(tokens[i_start]))) then
				if(	tokens[i_prev_index] == 'AS' or 
					tokens[i_prev_index] == ')' or 
					(sqlparsing.isidentifier(tokens[i_prev_index]) and not sqlparsing.iskeyword(tokens[i_prev_index])) or
					sqlparsing.isstringliteral(tokens[i_prev_index]) or 
					sqlparsing.isnumericliteral(tokens[i_prev_index])
				) then 
					t_col[i]['ALIAS'] = i_start
					if(tokens[i_prev_index] == 'AS') then 
						t_col[i]['EXPRESSION_END'] = sqlparsing.find(tokens, i_prev_index -1, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
					else 
						t_col[i]['EXPRESSION_END'] = i_prev_index
					end
	
				else 
					tmp_table_column_name = get_table_column_name(tokens[i_start])
					t_col[i]['IDENTIFIER'][#t_col[i]['IDENTIFIER'] +1] = {
						['START'] = i_start, 
						['END'] = i_start,
						['TABLE_NAME'] = tmp_table_column_name['TABLE_NAME'], 
						['COLUMN_NAME'] = tmp_table_column_name['COLUMN_NAME']
				}
				end
				
			-- table_alias.column_name
			elseif(sqlparsing.isidentifier(tokens[i_start]) and not sqlparsing.iskeyword(tokens[i_start])) then
				tmp_table_column_name = get_table_column_name(tokens[i_start])
				t_col[i]['IDENTIFIER'][#t_col[i]['IDENTIFIER'] +1] = {
					['START'] = i_start, 
					['END'] = i_start,
					['TABLE_NAME'] = tmp_table_column_name['TABLE_NAME'], 
					['COLUMN_NAME'] = tmp_table_column_name['COLUMN_NAME']
				}

			end
			
			i_prev_index = i_start
			i_start = sqlparsing.find(tokens, i_start +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
			
			if(i_start == nil) then
				break
			else 
				i_start = i_start[1]
			end
		end
	end
	return t_col
end














/*
 * received the input parameter t_from from the set_from function
 * 
 * t_from[START/END] 									--> start index index of the from keyword, end index is the last index of the from clause
 * t_from[JOIN_GROUP] = {} 								--> join groups, a join group is a set of tables join with each other, a cartesian product starts a new join group
 * t_from[JOIN_GROUP][i] 								--> join group i
 * t_from[JOIN_GROUP][i][START/END] 					--> boundries of the join group i
 * t_from[JOIN_GROUP][i][TABLE] = {} 					--> tables of the join group i
 * t_from[JOIN_GROUP][i][TABLE][j] 						--> table j of the join group i
 * t_from[JOIN_GROUP][i][TABLE][j][IDX/SCHEMA_NAME/TABLE_NAME/ALIAS] --> idx, schema and table name and alias index of the table j of the join group i
 * t_from[JOIN_GROUP][i][TABLE][j][COLUMN_NAME] = {}	--> columns of the table j in the join group i
 * t_from[JOIN_GROUP][i][TABLE][j][COLUMN_NAME][k]		--> column k of the table j in the join group i
 * 
 * pivot subsection is defined by the find_pivot function
 * see find_pivot for details of the pivot structure
 * */
function set_from(tokens, t_from)

	local t_from = t_from
	t_from['JOIN_GROUP'] = {}
	local t_columns = {}
	local i_table_name = -1
	local i_pos = t_from['START'] +1
	local i_next = -1

	
	--splits the from clause into its different coherent join groups --> cartesian products seperate join groups
	tmp_from = get_cst(tokens, i_pos, t_from['END'])
	
	--analyse the join groups
	for i=1, #tmp_from do
		
		
		t_from['JOIN_GROUP'][i] = tmp_from[i]
		t_from['JOIN_GROUP'][i]['TABLE'] = {}
		t_from['JOIN_GROUP'][i]['PIVOT'] = {}
		i_pos = sqlparsing.find(tokens, t_from['JOIN_GROUP'][i]['START'], true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
		
		
		--repeat until the current position is smaller than the end index of the join group
		while i_pos <= t_from['JOIN_GROUP'][i]['END'] do
			i_table_name = -1
		
			--if identifier and not keyword --> table_name
			if(sqlparsing.isidentifier(tokens[i_pos]) and not sqlparsing.iskeyword(tokens[i_pos])) then
				i_table_name = i_pos
				--extract schema and table name from identifier token
				t_schema_table_name = get_schema_table_name(tokens[i_table_name])
				t_from['JOIN_GROUP'][i]['TABLE'][#t_from['JOIN_GROUP'][i]['TABLE'] +1] = {
					['IDX'] = i_table_name, 
					['SCHEMA_NAME'] = t_schema_table_name['SCHEMA'], 
					['TABLE_NAME'] = t_schema_table_name['TABLE'],
					['ALIAS'] = -1, 
					['COLUMN_NAME'] = {}
				}
				
				--the next non whitespace/comment element, after the table name
				i_pos = sqlparsing.find(tokens, i_pos +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
				if(i_pos == nil) then
					return t_from
				else 
					i_pos = i_pos[1]
					if(i_pos > t_from['JOIN_GROUP'][i]['END']) then
						break
						
					--if identifier and not keyword --> alias
					elseif(sqlparsing.isidentifier(tokens[i_pos]) and not sqlparsing.iskeyword(tokens[i_pos])) then 
						t_from['JOIN_GROUP'][i]['TABLE'][#t_from['JOIN_GROUP'][i]['TABLE']]['ALIAS'] = i_pos
						
					--if next is AS --> look next
					elseif(tokens[i_pos] == 'AS') then
						i_pos = sqlparsing.find(tokens, i_pos +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
						if(i_pos == nil) then 
							error('expected a table alias')
						else
							i_pos = i_pos[1]
							if(i_pos > t_from['JOIN_GROUP'][i]['END']) then
								error('expected a table alias')
							
								--if identifier and not keyword --> alias
							elseif(sqlparsing.isidentifier(tokens[i_pos]) and not sqlparsing.iskeyword(tokens[i_pos])) then 
								t_from['JOIN_GROUP'][i]['TABLE'][#t_from['JOIN_GROUP'][i]['TABLE']]['ALIAS'] = i_pos
								
							end
						end
					end
				end
				
				
				--get column names of the table
				t_columns = query_column_name(t_schema_table_name['SCHEMA_NAME'], t_schema_table_name['TABLE_NAME'])
				for j=1, #t_columns do
					t_from['JOIN_GROUP'][i]['TABLE'][#t_from['JOIN_GROUP'][i]['TABLE']]['COLUMN_NAME'][j] = t_columns[j]['COLUMN_NAME']
				end	
				
				-- prepare next iteration
				i_next = sqlparsing.find(tokens, i_pos +1, true, true, sqlparsing.iswhitespaceorcomment, 'JOIN')
				if(i_next == nil) then
					--maybe there is no join anymore, there could be a pivot
					t_from['JOIN_GROUP'][i]['PIVOT'] = find_pivot(tokens, i_pos +1, t_from['JOIN_GROUP'][i]['END'])
					break
				else
					i_next = i_next[1]
					if(i_next > t_from['JOIN_GROUP'][i]['END']) then
						--if there is a join, but its outside the join group broundries, maybe there is a pivot within the boundries
						t_from['JOIN_GROUP'][i]['PIVOT'] = find_pivot(tokens, i_pos +1, t_from['JOIN_GROUP'][i]['END'])
						break
					else
						-- find next non whitespace/comment token after join
						i_next = sqlparsing.find(tokens, i_next +1, true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
						if(i_next == nil) then
							break
						else
							i_pos = i_next[1]
							if(i_pos > t_from['JOIN_GROUP'][i]['END']) then
								break
							end
						end
					end
				end
			else
				error('expected an table/view name, but got this: ' .. tokens[i_pos])
			end
		end
	end	
	return t_from
end





/*
 * t_pivot[START] 	--> index of the pivot keyword
 * t_pivot[OPENING] --> index of the opening bracket of the pivot function
 * t_pivot[CLOSING] --> index of the corresponding closing bracket of the pivot keyword
 * t_pivot[ALIAS] 	--> index of the pivot alias, if the pivot function has one, else -1
 * t_pivot[END] 	--> index of the end of the pivot function, either the same index as CLOSING or ALIAS
 * 
 * further pivot subsections are set by the set_pivot function
 * see set_pivot for more details
 * */
function find_pivot(tokens, first, last)
	local i_first = sqlparsing.find(tokens, first, true, false, sqlparsing.iswhitespaceorcomment, 'PIVOT', '(')
	local i_last = sqlparsing.find(tokens, last, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
	
	local t_pivot = {
		['START'] = -1, 
		['OPENING'] = -1, 
		['CLOSING'] = -1, 
		['ALIAS'] = -1, 
		['END'] = -1
	}
	
	--no pivot
	if(i_first == nil) then
		return t_pivot
	else 
		i_pivot_closing = sqlparsing.find(tokens, i_first[2], true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
		
		--pivot not closed
		if(i_pivot_closing == nil) then
			error('pivot function not closed')
		else 
			i_pivot_closing = i_pivot_closing[1]
			t_pivot = {
				['START'] = i_first[1], 
				['OPENING'] = i_first[2], 
				['CLOSING'] = i_pivot_closing, 
				['ALIAS'] = -1, 
				['END'] = i_last
			}
			if(i_pivot_closing == i_last) then
				t_pivot = set_pivot(tokens, t_pivot)
				return t_pivot
			end
		end
		
		--searching for pivot alias
		i_pivot_alias = sqlparsing.find(tokens, i_pivot_closing +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
		
		--no pivot alias
		if(i_pivot_alias == nil) then
			t_pivot = set_pivot(tokens, t_pivot)
			return t_pivot
		else
			i_pivot_alias = i_pivot_alias[1]
			
			--next token is outside the boundries
			if(i_pivot_alias > i_last) then
				t_pivot = set_pivot(tokens, t_pivot)
				return t_pivot
				
			--token is an alias
			elseif(sqlparsing.isidentifier(tokens[i_pivot_alias]) and not sqlparsing.iskeyword(tokens[i_pivot_alias]) and i_pivot_alias == i_last) then
				t_pivot['ALIAS'] = i_pivot_alias
				t_pivot = set_pivot(tokens, t_pivot)
				return t_pivot
				
			--alias expected after AS
			elseif(tokens[i_pivot_alias] == 'AS') then 
				i_pivot_alias = sqlparsing.find(tokens, i_pivot_alias +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
				
				--there is no next
				if(i_pivot_alias == nil) then 
					error('expected an pivot alias (1)')
				else 
					i_pivot_alias = i_pivot_alias[1]
					
					--next token is outside the search boundries
					if(i_pivot_alias > i_last) then 
						error('expected an pivot alias (2)')
						
					--found an alias
					elseif(sqlparsing.isidentifier(tokens[i_pivot_alias]) and not sqlparsing.iskeyword(tokens[i_pivot_alias]) and i_pivot_alias == i_last) then 
						t_pivot['ALIAS'] = i_pivot_alias
						t_pivot = set_pivot(tokens, t_pivot)
						return t_pivot
					else 
						error('pivot alias is not valid')
					end 
				end 
			end 
		end
	end	
end







/*
 * expects the structure of the returned table by the find_pivot function
 * adds the following section/subections to the t_pivot table
 * some of the content/structure for the FOR clause is defined by the get_col_list function
 * see the get_col_list function for more details
 * 
 * 
 * t_pivot[AGGREGATE] 									--> contains the relevant indexes for the aggregate section
 * t_pivot[AGGREGATE][START/END] 						--> index of the first token of the first aggregate function, index of the last token of the last aggregate function
 * t_pivot[AGGREGATE][FUNCTION] = {} 					====> populated by get_col_list
 * t_pivot[AGGREGATE][FUNCTION][i] 						--> details for function i
 * 
 * t_pivot[FOR] 										--> contains the relevant indexes of the for clause
 * t_pivot[FOR][START/OPENING/END] 						--> index of the FOR keyword, the opening bracket and the closing bracket
 * t_pivot[FOR][COLUMN] = {} 							--> contains the information about the for columns to pivot over
 * t_pivot[FOR][COLUMN][i] 								--> details about the column i
 * t_pivot[FOR][COLUMN][i][START/END] 					--> since its identifiers here, start and end are usually equal
 * 
 * t_pivot[IN] 											--> contains the relevant indexes of the
 * t_pivot[IN][START/OPENING/END] 						--> index of the IN keyword, the opening bracket and the closing bracket
 * t_pivot[IN][VALUE_GROUP] = {} 						--> contains the number of value tuples in the IN clause. each value group contains the as many values as columns in the FOR clause
 * t_pivot[IN][VALUE_GROUP][i] 							--> value group i
 * t_pivot[IN][VALUE_GROUP][i][VALUE] = {} 				--> contains the values of the value group i
 * t_pivot[IN][VALUE_GROUP][i][VALUE][j] = {} 			--> contains details of value j of the value group i
 * t_pivot[IN][VALUE_GROUP][i][VALUE][j][START/END] 	--> index of the first and last token of a value. only static values allowed. when using transformation of static values, start and end index can be different, for example "to_date('01.01.2020', 'DD.MM.YYYY')"
 * */
function set_pivot(tokens, t_pivot)
	local t_pivot = t_pivot
	
	--find the start and end boundries for the AGGREGATES, the FOR clause and the IN clause
	local i_pivot_agg_start = sqlparsing.find(tokens, t_pivot['OPENING'] +1, true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
	if(i_pivot_agg_start == nil) then error('AGGREGTES in the PIVOT function are missing (1)') end 
	
	local i_pivot_for_start = sqlparsing.find(tokens, t_pivot['OPENING'] +1, true, true, sqlparsing.iswhitespaceorcomment, 'FOR', '(')
	if(i_pivot_for_start == nil) then error('FOR clause in the PIVOT function is missing') end 
	
	local i_pivot_in_start = sqlparsing.find(tokens, i_pivot_for_start[1], true, true, sqlparsing.iswhitespaceorcomment, 'IN', '(')
	if(i_pivot_in_start == nil) then error('IN clause in the PIVOT function is missing') end 

	local i_pivot_agg_end = sqlparsing.find(tokens, i_pivot_for_start[1] -1, false, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
	if(i_pivot_agg_end == nil) then error('AGGREGATES in the PIVOT function are missing (2)') end 

	local i_pivot_for_end = sqlparsing.find(tokens, i_pivot_for_start[2], true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
	if(i_pivot_for_end == nil) then error('closing brackets of the FOR clause is missing') end 

	local i_pivot_in_end = sqlparsing.find(tokens, i_pivot_in_start[2], true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
	if(i_pivot_in_end == nil) then error('closing brackets of the IN clause is missing') end 
	
	
	--set the base indexes of the clauses of the pivot function
	t_pivot['AGGREGATE'] = {
		['START'] = i_pivot_agg_start[1], 
		['END'] = i_pivot_agg_end[1],
		['FUNCTION'] = {}
	}
	t_pivot['FOR'] = {
		['START'] = i_pivot_for_start[1], 
		['OPENING'] = i_pivot_for_start[2], 
		['END'] = i_pivot_for_end[1],
		['COLUMN'] = {}
	}
	t_pivot['IN'] = {
		['START'] = i_pivot_in_start[1], 
		['OPENING'] = i_pivot_in_start[2], 
		['END'] = i_pivot_in_end[1],
		['VALUE_GROUP'] = {}
	}
	
	-- set aggregate functions
	t_pivot['AGGREGATE']['FUNCTION'] = set_col_list(tokens, {['START'] = t_pivot['OPENING'], ['END'] = i_pivot_for_start[1] -1})
	t_pivot['AGGREGATE']['FUNCTION']['DISTINCT'] = nil
	if(#t_pivot['AGGREGATE']['FUNCTION'] == 0) then 
		error('no AGGREGATE functions in PIVOT defined')
	end
		
	--set for columns
	t_pivot['FOR']['COLUMN'] = get_cst(tokens, t_pivot['FOR']['OPENING'] +1, t_pivot['FOR']['END'] -1)
	if(#t_pivot['FOR']['COLUMN']  == 0) then 
		error('no columns in the FOR clause of the PIVOT function defined')
	end
	
	
	-- set in values
	local i_in_group_sep = t_pivot['IN']['OPENING']
	
	-- if 1 column to pivot over
	if(#t_pivot['FOR']['COLUMN']  == 1) then 
		local tmp_in = get_cst(tokens, t_pivot['IN']['OPENING'] +1, t_pivot['IN']['END'] -1)	
		if(#tmp_in == 0) then 
			error('no values in the IN clause of the PIVOT function defined')
		end
		
		for i=1, #tmp_in do
			if(not check_static_values(tokens, tmp_in[i]['START'], tmp_in[i]['END'])) then 
				error('only static values can be used in the IN caluse of the PIVOT function')
			end
			
			--setting group boundries
			t_pivot['IN']['VALUE_GROUP'][i] = {
				['START'] = tmp_in[i]['START'],  
				['END'] = tmp_in[i]['END'],
				['VALUE'] = {}
			}
			
			--setting value in group boundries
			t_pivot['IN']['VALUE_GROUP'][i]['VALUE'][1] = {
				['START'] = tmp_in[i]['START'], 
				['END'] = tmp_in[i]['END']
			}
		end 
	
	--if more than 1 column to pivot over
	elseif(#t_pivot['FOR']['COLUMN']  >= 2) then 
		while true do 
			--find group start
			local i_in_group_start = sqlparsing.find(tokens, i_in_group_sep +1, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
			if(tokens[i_in_group_start] ~= '(') then 
				error('expected an "(" for the value group in the IN clause of the PIVOT function')
			end
			
			--find group end
			local i_in_group_end = sqlparsing.find(tokens, i_in_group_start, true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
			if(i_in_group_end == nil) then 
				error('expected an ")" for the end of the value group in the IN clause of the PIVOT function')
			else
				i_in_group_end = i_in_group_end[1]
			end
			
			--set value group boundries
			t_pivot['IN']['VALUE_GROUP'][#t_pivot['IN']['VALUE_GROUP'] +1] = {
				['START'] = i_in_group_start, 
				['END'] = i_in_group_end,
				['VALUE'] = {}
			}
			
			--get values within the group
			local tmp_in = get_cst(tokens, i_in_group_start +1, i_in_group_end -1)
			if(#tmp_in ~= #t_pivot['FOR']['COLUMN']) then 
				error('not the correct number of values in the value group of the IN clause in the PIVOT function')
			end
			
			--set the values within the value group
			for i=1, #tmp_in do
				if(not check_static_values(tokens, tmp_in[i]['START'], tmp_in[i]['END'])) then 
					error('only static values can be used in the IN caluse of the PIVOT function')
				end
				t_pivot['IN']['VALUE_GROUP'][#t_pivot['IN']['VALUE_GROUP']]['VALUE'][i] = {
					['START'] = tmp_in[i]['START'], 
					['END'] = tmp_in[i]['END']
				}
			end
			
			--find group separator
			i_in_group_sep = sqlparsing.find(tokens, i_in_group_end +1, true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
			if(i_in_group_sep == nil) then 
				break
			elseif(tokens[i_in_group_sep[1]] ~= ',') then 
				error('expected a comma to seperate value groups in the IN clause')
			else 
				i_in_group_sep = i_in_group_sep[1]
			end
		end		
	end
	return t_pivot
	
	
end



/*
 * generates the sql to perform the pivot, returns a sql string
 * */
function gen_pivot_sql(tokens, t_sql_structure) 
	
	--generate the case statements with each value within the value group of the in clause compared with the corresponding column of the for clause
	--part of the pivot column alias, that consists of the values of the value group is generated too
	local t_case = {['JOIN_GROUP'] = {}}
	local s_op = ''
	
	for i=1, #t_sql_structure['FROM']['JOIN_GROUP'] do 
		t_case['JOIN_GROUP'][i] = {}
		if(t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['START'] > 0) then
			for j=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'] do
				local s_case_expr = 'CASE WHEN '
				local s_value_alias = ''
				for k=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE'] do 
					if(tokens[t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE'][k]['START']] == 'NULL') then 
						s_op = ' IS '
					else
						s_op = ' = '
					end			
					s_value_alias = s_value_alias .. table.concat(tokens, '', t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE'][k]['START'], t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE'][k]['END'])
					s_case_expr = s_case_expr .. table.concat(tokens, '', t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['FOR']['COLUMN'][k]['START'], t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['FOR']['COLUMN'][k]['END']) .. s_op .. table.concat(tokens, '', t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE'][k]['START'], t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE'][k]['END'])
					if(k < #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['IN']['VALUE_GROUP'][j]['VALUE']) then 
						s_case_expr = s_case_expr .. ' AND '
						s_value_alias = s_value_alias .. '_'
					else 
						s_case_expr = s_case_expr .. ' THEN '
					end 
				end
				t_case['JOIN_GROUP'][i][#t_case['JOIN_GROUP'][i] +1] = {['EXPRESSION'] = s_case_expr, ['VALUE_ALIAS'] = s_value_alias}
			end 
		end
	end
		
	--wrapping the case statements around all the column references of the aggregate functions
	local tmp_case_agg = subrange(tokens, 1, #tokens)
	local t_case_agg = {['JOIN_GROUP'] = {}}	
	local s_agg_alias = ''
	
	for i=1, #t_case['JOIN_GROUP'] do 
		t_case_agg['JOIN_GROUP'][i] = {}
		for j=1, #t_case['JOIN_GROUP'][i] do 
			if(t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['START'] > 0) then
				for k=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'] do
					for l=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['IDENTIFIER'] do
						tmp_case_agg[t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['IDENTIFIER'][l]['START']] = t_case['JOIN_GROUP'][i][j]['EXPRESSION'] .. tokens[t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['IDENTIFIER'][l]['START']] .. ' END'
					end
					if(t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['ALIAS'] < 0) then
						s_agg_alias = 'A_' .. i .. '_' .. j
					else
						s_agg_alias = tokens[t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['ALIAS']]
					end
					t_case_agg['JOIN_GROUP'][i][#t_case_agg['JOIN_GROUP'][i] +1] = {
						['EXPRESSION'] = table.concat(subrange(tmp_case_agg, t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['START'], t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][k]['EXPRESSION_END'])), 
						['ALIAS'] = quote(t_case['JOIN_GROUP'][i][j]['VALUE_ALIAS'] .. '_' .. unquote(s_agg_alias))
					}
				end
			end
		end
	end
	
	
	--collect columns in the aggregate functions and for clause to exclude them from the group by clause
	--unique column names only, see oracle functionality
	local t_agg_cols = {}
	for i=1, #t_sql_structure['FROM']['JOIN_GROUP'] do
		if(t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['START'] > 0) then
		
			--columns that are used in aggrate functions to check against coumns of used tables (used for the right grouping)
			for j=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'] do 
				for k=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][j]['IDENTIFIER'] do					
					t_agg_cols[unquote(t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][j]['IDENTIFIER'][k]['COLUMN_NAME'])] = t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['AGGREGATE']['FUNCTION'][j]['IDENTIFIER'][k]['START']
				end
			end
		
			--collect columns that are used in the for clause to check against coumns of used tables (used for the right grouping)
			for k=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['FOR']['COLUMN'] do
				t_agg_cols[unquote(tokens[t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['FOR']['COLUMN'][k]['START']])] = t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['FOR']['COLUMN'][k]['START']
			end	
			
		end
	end
		
	
	--columns to group by: columns that arent used in the for clause or aggregation functions
	local t_group_by_cols = {['JOIN_GROUP'] = {}}
	for i=1, #t_sql_structure['FROM']['JOIN_GROUP'] do
		t_group_by_cols['JOIN_GROUP'][i] = {}
		for j=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['TABLE'] do
			for k=1, #t_sql_structure['FROM']['JOIN_GROUP'][i]['TABLE'][j]['COLUMN_NAME'] do
				if(t_agg_cols[unquote(t_sql_structure['FROM']['JOIN_GROUP'][i]['TABLE'][j]['COLUMN_NAME'][k])] == nil) then
					t_group_by_cols['JOIN_GROUP'][i][#t_group_by_cols['JOIN_GROUP'][i] +1] = quote(t_sql_structure['FROM']['JOIN_GROUP'][i]['TABLE'][j]['COLUMN_NAME'][k])
				end
			end
		end
	end

	
	
	
	--add the group by columns to an existing group by clause, or generate one
	local s_group_by = ''
	for i=1, #t_group_by_cols['JOIN_GROUP'] do
		if(#t_group_by_cols['JOIN_GROUP'][i] > 0) then 
			if(#s_group_by > 0) then
				s_group_by = s_group_by .. ', '
			end 
			s_group_by = s_group_by .. table.concat(t_group_by_cols['JOIN_GROUP'][i], ', ')
		end
	end
	if(t_sql_structure['GROUP']['START'] > 0) then 
		s_group_by = table.concat(tokens, '', t_sql_structure['GROUP']['START'], t_sql_structure['GROUP']['END']) .. ', ' .. s_group_by
	else 
		s_group_by = 'GROUP BY ' .. s_group_by
	end

	
	--alter select list only if it contains: *, pivot_alias.*, pivot_alias.pivot_col, pivot_col
	local tmp_select = subrange(tokens, 1, #tokens)
	for i=1, #t_sql_structure['SELECT'] do
		for j=1, #t_sql_structure['SELECT'][i]['IDENTIFIER'] do 

			--pivot_alias.*, * --> replace all
			if(t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['COLUMN_NAME'] == '*') then		
				local tmp_case_agg = {}
				for l=1, #t_case_agg['JOIN_GROUP'] do
					if(t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['TABLE_NAME'] == '' or t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['TABLE_NAME'] == unquote(tokens[t_sql_structure['FROM']['JOIN_GROUP'][l]['PIVOT']['ALIAS']])) then
												
						if(tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] ~= '') then
							for k=t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START'], t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['END'] do
								tmp_select[k] = ''
							end
						end
					
						for n=1, #t_group_by_cols['JOIN_GROUP'][l] do
							tmp_case_agg[#tmp_case_agg +1] = t_group_by_cols['JOIN_GROUP'][l][n]
						end
						
						for m=1, #t_case_agg['JOIN_GROUP'][l] do
							tmp_case_agg[#tmp_case_agg +1] = t_case_agg['JOIN_GROUP'][l][m]['EXPRESSION'] .. ' AS ' .. t_case_agg['JOIN_GROUP'][l][m]['ALIAS']
						end
						
						if(tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] ~= '') then
							tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] = tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] .. ', ' .. table.concat(tmp_case_agg, ', ')						
						else
							tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] = table.concat(tmp_case_agg, ', ')	
						end
					end
				end
			
			else	
				n_hit = 0
				for n=1, #t_case_agg['JOIN_GROUP'] do
					for m=1, #t_case_agg['JOIN_GROUP'][n] do					
						if(((#t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['TABLE_NAME'] > 0 and t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['TABLE_NAME'] == unquote(tokens[t_sql_structure['FROM']['JOIN_GROUP'][n]['PIVOT']['ALIAS']])) or
							(#t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['TABLE_NAME'] == 0)
						   ) and t_case_agg['JOIN_GROUP'][n][m]['ALIAS'] == quote(t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['COLUMN_NAME'])) then
							if(t_sql_structure['SELECT'][i]['START'] == t_sql_structure['SELECT'][i]['END']) then
								tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] = t_case_agg['JOIN_GROUP'][n][m]['EXPRESSION'] .. ' AS ' .. t_case_agg['JOIN_GROUP'][n][m]['ALIAS']
								n_hit = n_hit +1
							else 
								tmp_select[t_sql_structure['SELECT'][i]['IDENTIFIER'][j]['START']] = t_case_agg['JOIN_GROUP'][n][m]['EXPRESSION']
								n_hit = n_hit +1
							end
						end
						if(n_hit > 1) then 
							error('pivot column selection is ambigous')
						end
					end
				end				
			end
		end
	end
		
	
	-- find the indexes where the group by statement can be inserted into the statement
	local i_pre_group = nil
	local i_post_group = nil
	if(t_sql_structure['GROUP']['START'] > 0) then
		i_pre_group = t_sql_structure['GROUP']['START'] -1
		i_post_group = t_sql_structure['GROUP']['END'] +1
	else

		i_pre_group = math.max(
			t_sql_structure['FROM']['END'], 
			t_sql_structure['WHERE']['END'],
			t_sql_structure['CONNECT']['END'],
			t_sql_structure['PREFERRING']['END']
		)
		i_post_group = math.min(
			t_sql_structure['HAVING']['START'], 
			t_sql_structure['QUALIFY']['START'], 
			t_sql_structure['ORDER']['START'], 
			t_sql_structure['LIMIT']['START'],
			#tokens
		)
		--if e.g. there is no where keyword in the sql text, the index is -1
		if(i_post_group < 0) then 
			i_post_group = i_pre_group
		end
	end
	
	
	--generate the final sql
	local s_from = ''
	local i_from_join_end = -1
	for i=1, #t_sql_structure['FROM']['JOIN_GROUP'] do
		if(i > 1) then
			s_from = s_from .. ', '
		end
		if(t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['START'] > 0) then
			i_from_join_end = t_sql_structure['FROM']['JOIN_GROUP'][i]['PIVOT']['START'] -1
		else
			i_from_join_end = t_sql_structure['FROM']['JOIN_GROUP'][i]['END']
		end
		s_from = s_from .. ' ' .. table.concat(tokens, '', t_sql_structure['FROM']['JOIN_GROUP'][i]['START'], i_from_join_end)
	end
	s_from = 'FROM ' .. s_from

	
	local s_sql = 
		table.concat(tokens, 		'', 1, 									t_sql_structure['SELECT']['START'] -1) .. ' ' ..
		table.concat(tmp_select, 	'', t_sql_structure['SELECT']['START'], t_sql_structure['SELECT']['END']) .. ' ' .. 
		s_from .. ' ' ..
		table.concat(tokens, 		'', t_sql_structure['FROM']['END'] +1, i_pre_group) .. ' ' ..
		s_group_by .. ' ' ..
		table.concat(tokens, 		'', i_post_group,			 			#tokens)
	
	return s_sql
end



/*
 * checks if tokens from the first index until the last index contains only static values
 * returns false, identifiers are encountered
 * */
function check_static_values(tokens, first, last)
	local first = sqlparsing.find(tokens, first, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
	local last = sqlparsing.find(tokens, last, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)[1]
	
	for i=first, last do 
		if(sqlparsing.isidentifier(tokens[i]) and not sqlparsing.iskeyword(tokens[i])) then 
			return false
		end
	end
	return true
end




/*
 * sql like nvl
 * */
function nvl(v1, v2)
	if(v1 == nil) then 
		return v2
	else 
		return v1
	end
end




/*
 * creates a comma seperated table with start and end indexes of every token
 * start = index of first possible token, e.g "(a,b,c,d,e)" --> index of the token after the "("
 * end = index of the last possible token,  e.g "(a,b,c,d,e)" --> index of the token before the ")"
 * */
function get_cst(tokens, first, last)
	local t_cst = {}
	local i_first = sqlparsing.find(tokens, first, true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
	local i_last = sqlparsing.find(tokens, last, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
	
	if(i_first == nil or i_last == nil) then 
		return {}
	elseif((i_last[1] - i_first[1]) < 0) then 
		return {}
	else 
		i_first = i_first[1]
		i_last = i_last[1]
	end
	
	local i_val_start = i_first
	local i_val_end = i_last
	--local i_val_end = -1 --c1
	while i_val_start <= i_last and i_val_end <= i_last do
		i_val_end = sqlparsing.find(tokens, i_val_start, true, true, sqlparsing.iswhitespaceorcomment, ',')
		if(i_val_end == nil) then 
			t_cst[#t_cst +1] = {['START'] = i_val_start, ['END'] = i_last}
			break
		else 
			i_val_end = i_val_end[1]
		end
		
		if(i_val_end > i_last) then 
			t_cst[#t_cst +1] = {['START'] = i_val_start, ['END'] = i_last}
			break
		else
			t_cst[#t_cst +1] = {['START'] = i_val_start, ['END'] = i_val_end -1}
			i_val_start = sqlparsing.find(tokens, i_val_end +1, true, true, sqlparsing.iswhitespaceorcomment, sqlparsing.isany)
			if(i_val_start == nil) then 
				break
			else 
				i_val_start = i_val_start[1]
			end
		end
	end
	return t_cst
end


/*
 * function that tokenizes and normalized a sql string
 * */
function get_tokens(sqltext) 
	local tokens = sqlparsing.tokenize(sqltext)
	for i=1, #tokens do 
		tokens[i] = sqlparsing.normalize(tokens[i])
	end
	return tokens
end




/*
 * helper function function to print all tokens and their matching types
 * */
function print_token_classes(tokens) 
	for i=1, #tokens do
		local token_type = ''
		if sqlparsing.iscomment(tokens[i]) then token_type = token_type .. ' comment' end
		if sqlparsing.iswhitespace(tokens[i]) then token_type = token_type .. ' whitespace' end
		if sqlparsing.iswhitespaceorcomment(tokens[i]) then token_type = token_type .. ' whitespaceorcomment' end
		if sqlparsing.isidentifier(tokens[i]) then token_type = token_type .. ' identifier' end
		if sqlparsing.iskeyword(tokens[i]) then token_type = token_type .. ' keyword' end
		if sqlparsing.isstringliteral(tokens[i]) then token_type = token_type .. ' stringliteral' end
		if sqlparsing.isnumericliteral(tokens[i]) then token_type = token_type .. ' numericliteral' end
		if sqlparsing.isany(tokens[i]) then token_type = token_type .. ' any' end
		
		output(i .. '  -  ' .. tokens[i] .. '  -  ' .. token_type)
	end
end



/*
 * function to query column names for a given schema and table name. returns userdata[row][colum_nr]
 * */
function query_column_name(schema_name, table_name)
	return query([[select column_name from exa_user_columns where column_schema = :s and column_table = :t order by column_ordinal_position]], {s=schema_name, t=table_name})
end


/*
 * function to unquote strings. it assumes that strings are trimmed already. returns string
 * */
function unquote(str)
	if(string.sub(str, 1, 1) == '"' and string.sub(str, #str, #str) == '"') then
		return string.sub(str, 2, #str -1)
	else
		return str
	end
end




/*
 * returns a table that consists of the of the entries between the first and last index
 * */
function subrange(t, first, last)
	local sub = {}
	for i=first,last do
		sub[#sub + 1] = t[i]
	end
  	return sub
end




/*
 * function to splits a string by a "." into a schema and table name and removes
 * if there is no "." the string is considered to be the table name, in that case the current schema is returned
 * quoted schema or table names will be unquoted
 * returns string, string
 * */
function get_schema_table_name(identifier) 
	local t = {}
	for str in string.gmatch(identifier, [[([^\.]+)]]) do 
		table.insert(t, unquote(str))
	end
	if(#t == 1) then 
		return {['SCHEMA_NAME'] = exa.meta.current_schema, ['TABLE_NAME'] = t[1]}
	else 
		return {['SCHEMA_NAME'] = t[1], ['TABLE_NAME'] = t[2]}
	end
end



function get_table_column_name(identifier) 
	local t = {}
	for str in string.gmatch(identifier, [[([^\.]+)]]) do 
		table.insert(t, unquote(str))
	end
	if(#t == 1) then 
		return {['TABLE_NAME'] = '', ['COLUMN_NAME'] = t[1]}
	else 
		return {['TABLE_NAME'] = t[1], ['COLUMN_NAME'] = t[2]}
	end
end






function transform_pivot(sqltext)
	tokens = get_tokens(sqltext)
	--print_token_classes(tokens)
	t_sql_structure = get_sql_structure(tokens)
	pv = sqlparsing.find(tokens, 1, true, true, sqlparsing.iswhitespaceorcomment, 'PIVOT')
	if(pv ~= nil) then
		if(t_sql_structure['WITH']['START'] < 0) then
			t_sql_structure['SELECT'] = set_col_list(tokens, t_sql_structure['SELECT'])
			t_sql_structure['FROM'] = set_from(tokens, t_sql_structure['FROM'])

			return gen_pivot_sql(tokens, t_sql_structure)
		else
			error('with clauses with pivot are not supported.')
		end
	else
		return sqltext
	end
end

/
;

--/
create or replace script preprocessing.exa_preprocessors AS
	import('preprocessing.exa_pivot', 'exa_pivot')
	sqlparsing.setsqltext(
		exa_pivot.transform_pivot(sqlparsing.getsqltext())
	)
/
;

ALTER SESSION SET sql_preprocessor_script = preprocessing.exa_preprocessors;
--'';






select "p1"."1_122_MAX_SALES", p2.*, n
from util."PV_TEST" pv join util.t_ten t on pv.week_day_number = t.n
pivot(
	max(sales) as max_sales,  min(SALES)
	for(week_day_number, store_id2) 
	in((1,122),(1,123),(1,124),(2,122),(2,123),(2,124),(3,122))

) "p1"
, util.atp a
pivot(
	avg(cnt) avg_cnt
	for(sn)
	in(1,3,5,7)
) p2
where a.sn = pv.week_day_number
group by true
order by 1
limit 100

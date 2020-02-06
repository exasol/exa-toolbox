--/
create or replace script preprocessing.transformations() as
-------------------------------------------------------------------------------------------------------------------------------------
--UTIL
-------------------------------------------------------------------------------------------------------------------------------------
function all_any_qualify(sqltext)
 local tokens = sqlparsing.tokenize(sqlparsing.normalize(sqltext)) 
 local arg1 = {'LIKE', 'ALL'}
 local arg1_replace = 'AND'
 local arg2 = {'LIKE', 'ANY'}
 local arg2_replace = 'OR'
 
 local arg1_pos = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg1))
 local arg2_pos
 
 if not arg1_pos then
        arg2_pos = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg2))
 end

 local argument_position
 local operator
 
 if arg1_pos then
        argument_position = arg1_pos[1]
        operator = arg1_replace
 
 elseif arg2_pos then
        argument_position = arg2_pos[1]
        operator = arg2_replace
 end
 return tokens, argument_position, #arg1, operator
end
----------


function gather_key_tokens(tokens, argument_position)
 local exists_most_recent_identifier = sqlparsing.find(tokens, argument_position, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isidentifier)
 
 local most_recent_identifier_pos
 if exists_most_recent_identifier then
        most_recent_identifier_pos = exists_most_recent_identifier[1]
 else
        most_recent_identifier_pos = 1
 end
 
 local open_level
 if open_level then
        open_level = sqlparsing.find(tokens, most_recent_identifier_pos, true, false, sqlparsing.iswhitespaceorcomment,'(')[1]
 else
        open_level = 1
 end
 
 local close_level
 if close_level then
        close_level = sqlparsing.find(tokens, open_level, true, false, sqlparsing.iswhitespaceorcomment, ')')[1]
 else
        close_level = #tokens
 end
 
 return most_recent_identifier_pos, open_level, close_level
end

-------------------------------------------------------------------------------------------------------------------------------------
--FUNCTIONS
-------------------------------------------------------------------------------------------------------------------------------------
function like_all_any(sqltext)  
 local tokens, argument_position, arg_length, operator = all_any_qualify(sqltext)
 local most_recent_identifier_pos, open_level, close_level
 
 if not argument_position then
        return sqltext
 else
        most_recent_identifier_pos, open_level, close_level = gather_key_tokens(tokens, argument_position, most_recent_identifier)
 end
 
 local output_buffer = {}
 for i = open_level, close_level do
        if i == open_level then
                table.insert(output_buffer, '(')
        end
        
        if sqlparsing.isstringliteral(tokens[i]) then
                table.insert(output_buffer, tokens[most_recent_identifier_pos]..' LIKE '..tokens[i])
                if i ~= close_level - 1 then
                        table.insert(output_buffer, ' '..operator..' ')
                end
        end
        
        if i == close_level then
                table.insert(output_buffer, ')')
        end
 end 
 
 -- recursive call to replace every occurence
 return like_all_any(   table.concat(tokens, '', 1, argument_position - arg_length - 1)..       -- preceding SQL
                        table.concat(output_buffer,'')..                                        -- transformed SQL
                        table.concat(tokens, '', close_level + 1))                              -- succeeding SQL
end
-----------
--Tests
--output(like_all_any([[SELECT * FROM retail.article WHERE description like any('%in%',/*some comment*/'%Mix%','%c%')]]))
--output(like_all_any([[SELECT * FROM MYTABLE WHERE COL1 LIKE any('%a',/*some comment*/'%b%','c%') or col2 like all('%d',/*some other comment*/'%e%','f%')]], 1))
--output(like_all_any([[select * from retail.article where description like all('%in%', '%in%') and (description like any('%in%', '%in%') or description like all ('%b%','%c%'))]]))
--output(like_all_any([[select *  from retail.article where description like any('%be%','%s%')]]))
-----------


function index_to_locate(sqltext)
 local tokens = sqlparsing.tokenize(sqlparsing.normalize(sqltext))
 local arg1 = {'INDEX'}
 local arg1_replace = 'LOCATE'
 local arg1_pos = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg1))
 
 local argument_position
 local open_level
 local close_level
 
 if arg1_pos then
        argument_position = arg1_pos[1]
 else
        return(sqltext)
 end

 local _, open_level, close_level = gather_key_tokens(tokens, argument_position)
 
 local output_buffer = {}
 for i = open_level, close_level do  
        if sqlparsing.isidentifier(tokens[i]) then
                nearest_string = tokens[sqlparsing.find(tokens, i, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isstringliteral)[1]]
                table.insert(output_buffer, ' LOCATE('..nearest_string..','..tokens[i]..')')
        
        end
 end
  
 -- recursive call to replace every occurence
 return index_to_locate(table.concat(tokens, '', 1, argument_position - #arg1 - 1)..    -- preceding SQL
                        table.concat(output_buffer,'')..                                -- transformed SQL
                        table.concat(tokens, '', close_level + 1))                      -- succeeding SQL
  
end
-----------
--Tests
--output(index_to_locate([[SELECT INDEX(description, 'oma') as col1 FROM retail.article where INDEX(descripton, 'oma') > 0;]]))
-----------


function not_equal(sqltext)
 local tokens = sqlparsing.tokenize(sqlparsing.normalize(sqltext))
 local arg1 = {'NE'}
 local arg1_replace = '<>'
 local arg1_pos = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg1))

 local argument_position
 local open_level
 local close_level

 if arg1_pos then
        argument_position = arg1_pos[1]
 else
        return(sqltext)
 end

 local _, open_level, close_level = gather_key_tokens(tokens, argument_position)
 
 for i = open_level, close_level do  
        if sqlparsing.isidentifier(tokens[i]) and tokens[i] == 'NE' then
                tokens[i] = arg1_replace
        end
 end
 
 -- recursive call to replace every occurence
 return index_to_locate(table.concat(tokens, ''))   -- Transformed SQL
end
-----------
--Tests
--output(not_equal([[select * from retail.article where product_class NE 1]]))
--output(not_equal([[select * from retail.article where product_class NE 1 and product_class NE 0]]))
-----------
/

execute script preprocessing.transformations() with output;
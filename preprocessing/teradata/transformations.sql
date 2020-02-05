--/
create or replace script preprocessing.transformations() as
-------------------------------------------------------------------------------------------------------------------------------------
--UTIL
-------------------------------------------------------------------------------------------------------------------------------------
function all_any_qualify(sqltext)
 local tokens = sqlparsing.tokenize(sqlparsing.normalize(sqltext)) 
 local arg1 = {'LIKE', 'ALL'}
 local arg2 = {'LIKE', 'ANY'}
 local is_all = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg1))
 local is_any
 if not is_all then
        is_any = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg2))
 end

 local argument_position
 local operator
 
 if is_all then
        argument_position = is_all[1]
        operator = 'AND'
 
 elseif is_any then
        argument_position = is_any[1]
        operator = 'OR'
 end
 return tokens, argument_position, #arg1, operator
end


-------------------------------------------------------------------------------------------------------------------------------------
--FUNCTIONS
-------------------------------------------------------------------------------------------------------------------------------------
function like_all_any(sqltext, rec_depth)  
 local tokens, argument_position, arg_length, operator = all_any_qualify(sqltext)
 
 if not argument_position then
        return sqltext
 end
 
 local identifier = sqlparsing.find(tokens, argument_position, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isidentifier)[1]
 local open_level = sqlparsing.find(tokens, identifier, true, false, sqlparsing.iswhitespaceorcomment,'(')[1]
 local close_level = sqlparsing.find(tokens, open_level, true, false, sqlparsing.iswhitespaceorcomment, ')')[1]
 
 local output_buffer = {}
 for i = open_level, close_level do
        if i == open_level then
                table.insert(output_buffer, '(')
        end
        
        if sqlparsing.isstringliteral(tokens[i]) then
                table.insert(output_buffer, tokens[identifier]..' LIKE '..tokens[i])
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
                        table.concat(tokens, '', close_level + 1))                              -- succeding SQL
end
--output(like_all_any([[SELECT * FROM retail.article WHERE description like any('%in%',/*some comment*/'%Mix%','%c%')]]))
--output(like_all_any([[SELECT * FROM MYTABLE WHERE COL1 LIKE any('%a',/*some comment*/'%b%','c%') or col2 like all('%d',/*some other comment*/'%e%','f%')]], 1))
--output(like_all_any([[select * from retail.article where description like all('%in%', '%in%') and (description like any('%in%', '%in%') or description like all ('%b%','%c%'))]]))
/

--execute script preprocessing.transformations() with output;
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


function gather_key_tokens(tokens, argument_position, open_level_ident, close_level_ident)
 local exists_most_recent_identifier = sqlparsing.find(tokens, argument_position, false, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isidentifier)
 local most_recent_identifier_pos
 if exists_most_recent_identifier then
        most_recent_identifier_pos = exists_most_recent_identifier[1]
 else
        most_recent_identifier_pos = 1
 end
 
 local open_level_ident = open_level_ident
 if not open_level_ident then
        open_level_ident = '!="!§??'
 end
 
 local close_level_ident = close_level_ident
 if not close_level_ident then
        close_level_ident = '!="!§??' 
 end
 
 local open_level_exists = sqlparsing.find(tokens, most_recent_identifier_pos, true, false, sqlparsing.iswhitespaceorcomment, open_level_ident)
 local open_level_pos
 if open_level_exists then
        open_level_pos = open_level_exists[1]
 else
        open_level_pos = 1
 end
 
 
 local close_level_exists = sqlparsing.find(tokens, open_level_pos, true, true, sqlparsing.iswhitespaceorcomment, close_level_ident)
 local close_level_pos
 if close_level_exists then
        close_level_pos = close_level_exists[1]
 else
        close_level_pos = #tokens
 end
 
 return most_recent_identifier_pos, open_level_pos, close_level_pos
end
----------


function date_format_dql_lv2(sqltext)
 local tokens = sqlparsing.tokenize(sqlparsing.normalize(sqltext))
 local arg1 = {'CAST', '(', 'TO_CHAR' ,'(', sqlparsing.isidentifier, ',',sqlparsing.isstringliteral,')', 'AS', sqlparsing.iskeyword, '(', sqlparsing.isnumericliteral, ')'}
 local arg1_pos = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg1))

 
 local argument_position
 local open_level
 local close_level
 
 if arg1_pos then
        argument_position = arg1_pos[1]
 else
        return(sqltext)
 end
 
 local output_buffer = {}
 for i = argument_position + 2, arg1_pos[#arg1_pos - 6] do
        table.insert(output_buffer, tokens[i])
 end  

 -- recursive call to replace every occurence
 return date_format_dql(table.concat(tokens, '', 1, argument_position - 1)..        -- preceding SQL
                        table.concat(output_buffer,'')..                            -- transformed SQL
                        table.concat(tokens, '', arg1_pos[#arg1_pos] + 1))          -- succeeding SQL
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
        most_recent_identifier_pos, open_level, close_level = gather_key_tokens(tokens, argument_position, '(' , ')')
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
--output(like_all_any([[SELECT  a.description,
--        a.product_group_desc,
--        CAST(
--                CAST(sales_date AS FORMAT 'MM-DD-YYYY')
--                AS Varchar(10))
--                as col1,
--        index(a.description, 'tze') as tze_col,
--        a.product_class
--FROM retail.article a
--JOIN retail.sales s ON a.product_group = s.employee_id
--where index(a.description, 'Katze') > 0 and
--a.product_class NE 2 and
--a.description LIKE ALL('%o%',/*some comment*/'%e%') 
--and a.product_group_desc like any('%et%',/*some comment*/ '%p%');]]))
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

 local _, open_level, close_level = gather_key_tokens(tokens, argument_position, '(' , ')')
 
 local output_buffer = {}
 for i = argument_position + 1, close_level do  
        if sqlparsing.isidentifier(tokens[i]) then
                closest_string = tokens[sqlparsing.find(tokens, i, true, false, sqlparsing.iswhitespaceorcomment, sqlparsing.isstringliteral)[1]]
                table.insert(output_buffer, ' LOCATE('..closest_string..','..tokens[i]..')')
                break     
        end
 end
 
 -- recursive call to replace every occurence
 return index_to_locate(table.concat(tokens, '', 1, argument_position - #arg1)..    -- preceding SQL
                        table.concat(output_buffer,'')..                                -- transformed SQL
                        table.concat(tokens, '',  close_level + 1))                      -- succeeding SQL
  
end
-----------
--Tests
--output(index_to_locate([[SELECT INDEX(description, 'oma') as col1 FROM retail.article where INDEX(descripton, 'oma') > 0;]]))
--output(index_to_locate([[
--SELECT  a.description,
--        a.product_group_desc,
--        CAST(
--                CAST(sales_date AS FORMAT 'MM-DD-YYYY')
--                AS Varchar(10))
--                as col1,
--        index(a.description, 'es')
--FROM retail.article a
--JOIN retail.sales s ON a.product_group = s.employee_id
--where index(a.description, 'Katze') > 0 and
--a.product_class NE 1 and
--a.description LIKE ALL('%o%',/*some comment*/'%e%') 
--and a.product_group_desc like any('%et%',/*some comment*/ '%p%');]]))
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
--output(not_equal([[SELECT  a.description,
--        a.product_group_desc,
--        CAST(
--                CAST(sales_date AS FORMAT 'MM-DD-YYYY')
--                AS Varchar(10))
--                as col1,
--        index(a.description, 'es')
--FROM retail.article a
--JOIN retail.sales s ON a.product_group = s.employee_id
--where index(a.description, 'Katze') > 0 and
--a.product_class NE 1 and
--a.description LIKE ALL('%o%',/*some comment*/'%e%') 
--and a.product_group_desc like any('%et%',/*some comment*/ '%p%');]]))
-----------


function date_format_ddl(sqltext)
-- This is DDL. In contrast to Exasol, Teradata supports column dependent date formats, 
-- which can lead to inconsistencies in the data model.

-- In this DDL the date format is set to YYYY-MM-DD and it is assumed that all other 
-- DQL and DML statements work on this assumption. Forcing the DDL via the preprocessor 
-- to move to the Exasol format would only lead to a bang elsewhere.
end
-----------
--Tests
--
-----------

function date_format_dql(sqltext)
 --Level 1 - Remove inner CAST(col AS FORMAT 'str')
 local tokens = sqlparsing.tokenize(sqlparsing.normalize(sqltext))
 local arg1 = {'CAST', '(',sqlparsing.isidentifier ,'AS', 'FORMAT', sqlparsing.isstringliteral,')'}
 local arg1_replace = 'TO_CHAR'
 local arg1_pos = sqlparsing.find(tokens, 1, true, false, sqlparsing.iswhitespaceorcomment, unpack(arg1))
 
 local argument_position
 local open_level
 local close_level
 
 if arg1_pos then
        argument_position = arg1_pos[1]
 else
        --Level 2 - Remove outer CAST(col AS KEYWORD(n)) (if present)
        return(date_format_dql_lv2(sqltext))
 end
 local output_buffer = {arg1_replace..'(', tokens[arg1_pos[3]], ',', tokens[arg1_pos[6]]}   

  -- recursive call to replace every occurence
 return date_format_dql(table.concat(tokens, '', 1, argument_position - 1)..    -- preceding SQL
                        table.concat(output_buffer,'')..                        -- transformed SQL
                        table.concat(tokens, '', arg1_pos[#arg1_pos]))          -- succeeding SQL
end
-----------
--Tests
--output(date_format_dql([[SELECT CAST(CAST(date_point AS FORMAT 'YYYY-MM-DD')AS CHAR(10))AS col1]]))
-----------
/

execute script preprocessing.transformations() with output;
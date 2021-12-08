CREATE SCHEMA IF NOT EXISTS EXA_TOOLBOX;
--/
CREATE OR REPLACE SCRIPT EXA_TOOLBOX.GENERATE_VIEW(origin_schema,origin_table,number_of_tables,array table_name_array) AS
        
        -- set variables 
        res = query([[select table_schema, table_name from EXA_ALL_TABLES where :os = table_schema and :ot = table_name]],{os=origin_schema,ot=origin_table})
                
        -- Check if table exsits        
        if #res == 0 then 
                error("Table does not exists or privileges are missing.") else output("Table exisits")
        end
        
        -- quote for secure code execution
        
        origin_schema = quote(origin_schema) 
        origin_table = quote(origin_table)   
       
       -- build schema and table string 
        origin_st = origin_schema .. "." .. origin_table
        
        v_stmt = {}
        
        -- Decide if Array or num
        if number_of_tables == null then
                -- use array
                for a=1, #table_name_array do
                                                
                        create_stm = [[create or replace table ]].. origin_schema .. "." .. table_name_array[a] .." like ".. origin_st .. ";"
                        
                        suc, res = pquery(create_stm)
                                               
                        if not suc then
                          error('"'..res.error_message..'" Caught while executing: "'..res.statement_text..'"')
                        end      
                       
                        -- v_str = [[select * from ]] .. table_name_array[a] ..[[ union ]]
                        
                        if a == #table_name_array then
                                -- output("t == number: true")
                                v_str = [[select * from ]].. origin_st ..[[_]] .. a 
                       else
                                -- output("t==number: not true")
                                v_str = [[select * from ]].. origin_st ..[[_]] .. a ..[[ union all ]]
                       end
                        
                        table.insert(v_stmt,v_str)
                end
                
                output("generated " .. #table_name_array .. " tables successfully.")
        else
              
                -- GENERATE VIEW
                
                for t=1, number_of_tables do
                       
                       table_to_inst = quote(string.sub(origin_table,2,string.len(origin_table)-1) .. "_" .. t)
                        
                       -- output(table_to_inst) 
                        
                       create_stm = [[create or replace table ]].. origin_schema .. "." .. table_to_inst .." like " .. origin_st .. ";" 
                       
                       suc, res = pquery(create_stm)
                       
                       
                        if not suc then
                          error('"'..res.error_message..'" Caught while executing: "'..res.statement_text..'"')
                        end       
                       
                       
                       if t == number_of_tables then
                                -- output("t == number: true")
                                v_str = [[select * from ]].. origin_schema .. "." .. table_to_inst 
                       else
                                -- output("t==number: not true")
                                v_str = [[select * from ]].. origin_schema .. "." .. table_to_inst ..[[ 
                                union all ]]
                       end
                       
                       table.insert(v_stmt,v_str)
                       
                end
                
                output("generated " .. number_of_tables .. " tables successfully.")
        end
        
        -- 
        -- generate union statement from array
        v_stmt_txt = "(" .. table.concat(v_stmt,'') .. ")"
        
        -- remove quotes to add "_v"
        v_table_inst = origin_table:gsub([["]],[[]]) .. "_v" 
        
        -- and quotes and schema: "SCHEMA"."TABLE"
        v_table_and_schema = origin_schema .. "." .. quote(v_table_inst)
       
        -- out together all pieces and save the statement under v_total
        v_total = [[create or replace view ]] .. v_table_and_schema .. [[ as ]] .. v_stmt_txt
              
        -- execute create view statement
        suc, res = pquery(v_total)
        
        output("-- Creation Statement: " .. res.statement_text)
        
        if not suc then
               error('"'..res.error_message..'" Caught while executing: "'..res.statement_text..'"')
               else output("View and Tables successfully created.")
                   end     
        
        return res      
        
/

EXECUTE SCRIPT EXA_TOOLBOX.GENERATE_VIEW (  'retail' -- original schema
                                ,'CITIES' -- origin table 
                                ,20 -- Specifi the number of sub tables (if null array will be used)
                                ,ARRAY('table_1', 'table_2', 'table_3') -- array if you want to specify the names of the subtables
                                ) with output;
                                
                                

CREATE SCHEMA IF NOT EXISTS exa_toolbox;

/*
        This script creates DDL for a specified table.
        The DDL are presented as a single-column result-set and are ready for copy/paste into a text editor or SQL-editor for saving.
        
        Originally mentioned in article https://exasol.my.site.com/s/article/Create-DDL-for-a-table?language=en_US
		
        Params: source schema, source table, target schema, target table, replace_option (adds "OR REPLACE" to DDL when 'true').
*/

--/
create or replace script exa_toolbox.create_table_ddl(src_schema, src_table, trgt_schema, trgt_table, replace_option) returns table as
-- ############################ FUNCTIONS ############################

-- returns a table with columns: SCHEMA_NAME, TABLE_NAME, single column string (including identity and default)
function create_col_str(schema, table)
  res = query([[
                  with notnulls_constraints as
                  (
                     select * from EXA_ALL_CONSTRAINTS
                     where constraint_type = 'NOT NULL'
                  ),   notnulls_constraint_columns as
                  (
                    select * from EXA_ALL_CONSTRAINT_COLUMNS
                    where constraint_type = 'NOT NULL'
                  )
                  select '"'||COL.COLUMN_NAME||'" '||COLUMN_TYPE||
                         CASE WHEN COLUMN_IDENTITY IS NOT NULL THEN ' IDENTITY'
                                                               ELSE ''
                         END||
                         CASE WHEN COLUMN_DEFAULT IS NOT NULL THEN ' DEFAULT '||COLUMN_DEFAULT
                                                               ELSE ''
                         END||
                         CASE WHEN CC.CONSTRAINT_TYPE = 'NOT NULL' AND CON.CONSTRAINT_ENABLED     THEN ' NOT NULL ENABLE'
                              WHEN CC.CONSTRAINT_TYPE = 'NOT NULL' AND NOT CON.CONSTRAINT_ENABLED THEN ' NOT NULL DISABLE'
                                                                                                  ELSE ''
                         END
                         AS COLUMN_STR,
                         COLUMN_SCHEMA, COLUMN_TABLE, COLUMN_ORDINAL_POSITION, CC.CONSTRAINT_TYPE, CON.CONSTRAINT_ENABLED
                  from EXA_ALL_COLUMNS COL
                  left join notnulls_constraint_columns CC
                    on COL.COLUMN_SCHEMA = CC.CONSTRAINT_SCHEMA and COL.COLUMN_TABLE = CC.CONSTRAINT_TABLE and COL.COLUMN_NAME = CC.COLUMN_NAME
                  left JOIN notnulls_constraints CON
                    USING (constraint_schema, constraint_table, CONSTRAINT_NAME)
                  where COLUMN_SCHEMA = :sch
                    and COLUMN_TABLE  = :tab
                  order by COLUMN_ORDINAL_POSITION asc
                
              ]], {sch = schema, tab = table})
  if not (#res > 0) then
    error_str = "ERROR: column string query returned "..#res.." rows, expected more than 1."
    error_str = error_str.."Specified object might not exist" 
    error(error_str)
  end
  return res
end

-- creates DDL for primary key
-- returns bool(primary key exists), ddl(if pk exists)
function create_pk_str(src_schema, src_table, trgt_schema, trgt_table)
  res = query([[
                with pk_cols as (
                  SELECT constraint_schema, constraint_table, CONSTRAINT_NAME, CC.CONSTRAINT_TYPE, C.CONSTRAINT_ENABLED,
                         group_concat('"'||CC.column_name||'"' order by CC.ordinal_position) col_str
                  FROM EXA_ALL_CONSTRAINT_COLUMNS CC
                  JOIN EXA_ALL_CONSTRAINTS C
                    USING (constraint_schema, constraint_table, CONSTRAINT_NAME)
                  group by constraint_schema, constraint_table, CONSTRAINT_NAME, CC.CONSTRAINT_TYPE, C.CONSTRAINT_ENABLED
                )
                select 'ALTER TABLE '||:trgt_obj||' add constraint "'||CONSTRAINT_NAME||'" '||CONSTRAINT_TYPE||
                       '('||col_str||')'||
                       CASE WHEN CONSTRAINT_ENABLED THEN ' ENABLE'
                                                    ELSE ' DISABLE'
                       END||';' as DDL_TEXT
                FROM pk_cols
                where CONSTRAINT_SCHEMA = :sch
                  and CONSTRAINT_TABLE  = :tab
                  and CONSTRAINT_TYPE   = 'PRIMARY KEY'
               ]], {sch = src_schema, tab = src_table, trgt_obj=join('.', quote(trgt_schema), quote(trgt_table))})
  -- there is a pk
  if (#res == 1) then
    return true, res[1].DDL_TEXT
  -- no pk
  else
    return false
  end  
end

-- creates an array containing DDLs for foreign keys
-- returns bool(at least 1 foreign key exists), array with ddl(if fks exists)
function create_fk_str(src_schema, src_table, trgt_schema, trgt_table)
  res = query([[
                with pk_cols as (
                  SELECT constraint_schema, constraint_table, CONSTRAINT_NAME, CC.CONSTRAINT_TYPE, C.CONSTRAINT_ENABLED, CC.REFERENCED_SCHEMA, CC.REFERENCED_TABLE,
                         group_concat('"'||CC.column_name||'"' order by CC.ordinal_position) col_str,
                         group_concat('"'||CC.REFERENCED_COLUMN||'"' order by CC.ordinal_position) ref_str
                  FROM EXA_ALL_CONSTRAINT_COLUMNS CC
                  JOIN EXA_ALL_CONSTRAINTS C
                    USING (constraint_schema, constraint_table, CONSTRAINT_NAME)
                  group by constraint_schema, constraint_table, CONSTRAINT_NAME, CC.CONSTRAINT_TYPE, C.CONSTRAINT_ENABLED, CC.REFERENCED_SCHEMA, CC.REFERENCED_TABLE
                )
                select 'ALTER TABLE '||:trgt_obj||' add constraint "'||CONSTRAINT_NAME||'" '||CONSTRAINT_TYPE||
                       '('||col_str||')'||
                       ' REFERENCES "'||REFERENCED_SCHEMA||'"."'||REFERENCED_TABLE||'"('||ref_str||')'||
                       CASE WHEN CONSTRAINT_ENABLED THEN ' ENABLE'
                                                    ELSE ' DISABLE'
                       END||';' as DDL_TEXT
                FROM pk_cols
                where CONSTRAINT_SCHEMA = :sch
                  and CONSTRAINT_TABLE  = :tab
                  and CONSTRAINT_TYPE   = 'FOREIGN KEY'
               ]], {sch = src_schema, tab = src_table, trgt_obj=join('.', quote(trgt_schema), quote(trgt_table))})
  
  -- there are fks
  if (#res > 0) then
    return true, res
  -- no fk
  else
    return false
  end  
end

-- creates string for DISTRIBUTION KEY
-- returns false if no distribution key is specified, true and key string if distribution key is specified
function create_dist_key_str(src_schema, src_table, trgt_schema, trgt_table)
  res = query([[
                select 'ALTER TABLE '||:trgt_obj||' DISTRIBUTE BY '||GROUP_CONCAT('"'||column_name||'"' ORDER BY column_ordinal_position)||';' as DDL_TEXT
                from exa_all_columns
                where column_schema = :sch
                  and column_table  = :tab
                  and COLUMN_IS_DISTRIBUTION_KEY
                group by column_schema, column_table
              ]], {sch = src_schema, tab = src_table, trgt_obj=join('.', quote(trgt_schema), quote(trgt_table))})
  if (#res == 0) then
    return false
  else     
    return true, res[1].DDL_TEXT
  end
end

-- creates string for PARTITION KEY
-- returns false if no partition key is specified, true and key string if partition key is specified
function create_part_key_str(src_schema, src_table, trgt_schema, trgt_table)
  res = query([[
                select 'ALTER TABLE '||:trgt_obj||' PARTITION BY '||GROUP_CONCAT('"'||column_name||'"' ORDER BY COLUMN_PARTITION_KEY_ORDINAL_POSITION)||';' as DDL_TEXT
                from exa_all_columns
                where column_schema = :sch
                  and column_table  = :tab
                  and COLUMN_PARTITION_KEY_ORDINAL_POSITION is not null
                group by column_schema, column_table
              ]], {sch = src_schema, tab = src_table, trgt_obj=join('.', quote(trgt_schema), quote(trgt_table))})
  if (#res == 0) then
    return false
  else     
    return true, res[1].DDL_TEXT
  end
end

-- creates ddl for table comments (table and columns)
-- returns false if no comment specified, true and ddl if comment is specified
function create_table_comments(src_schema, src_table, trgt_schema, trgt_table)
  res = query([[
                select 'COMMENT ON TABLE '||:trgt_obj||' is '''||TABLE_COMMENT||'''' as DDL_TEXT
                from EXA_ALL_TABLES
                where table_schema = :sch
                  and table_name   = :tab                  
              ]], {sch = src_schema, tab = src_table, trgt_obj=join('.', quote(trgt_schema), quote(trgt_table))})
  res2 = query([[
                select GROUP_CONCAT('"'||column_name||'" is '''||column_comment||'''') as DDL_TEXT
                from EXA_ALL_COLUMNS
                where column_schema = :sch
                  and column_table  = :tab
                  and column_comment is not null
               ]], {sch=src_schema, tab=src_table})
  
  if(#res == 0 and res2[1].DDL_TEXT == null) then
    return false
  elseif (res2[1].DDL_TEXT ~= null) then
    res_str = res[1].DDL_TEXT..'('..res2[1].DDL_TEXT..');'
    return true, res_str    
  else 
    res_str = res[1].DDL_TEXT..';'
    return true, res_str
  end
end

-- creates ddl for column comment

-- ############################ SCRIPT BODY ############################

-- ##### create beginning ("CREATE [OR REPLACE] TABLE <<table_name>>")
beg_str = "CREATE"
if (replace_option) then
  beg_str = beg_str.." OR REPLACE"
end
beg_str = beg_str.." TABLE "..join('.', quote(trgt_schema), quote(trgt_table)).."("
ddl_str = beg_str

-- ##### get columns and create a row for each column 
col_strs = create_col_str(src_schema, src_table)

for i=1, #col_strs do
  -- last column: no comma
  if (i == #col_strs) then
    my_col_str = '    '..col_strs[i].COLUMN_STR
  -- other columns: comma
  else 
    my_col_str = '    '..col_strs[i].COLUMN_STR..', '
  end
  ddl_str = ddl_str..'\n'..my_col_str  
end

-- ##### close statement
ddl_str = ddl_str..'\n'..");"

-- ##### primary key
pk_exists, pk_str = create_pk_str(src_schema, src_table, trgt_schema, trgt_table)
if (pk_exists) then 
  ddl_str = ddl_str..'\n'..pk_str  
end

-- ##### foreign keys
fk_exists, fk_strs = create_fk_str(src_schema, src_table, trgt_schema, trgt_table)
if (fk_exists) then 
  for i=1,#fk_strs do
    ddl_str = ddl_str..'\n'..fk_strs[i][1]    
  end
end

-- ##### distribution key
dk_exists, dk_str = create_dist_key_str(src_schema, src_table, trgt_schema, trgt_table)
if (dk_exists) then
  ddl_str = ddl_str..'\n'..dk_str  
end

-- ##### partition key
dk_exists, dk_str = create_part_key_str(src_schema, src_table, trgt_schema, trgt_table)
if (dk_exists) then
  ddl_str = ddl_str..'\n'..dk_str  
end

-- ##### comments
comment_exists, comment_str = create_table_comments(src_schema, src_table, trgt_schema, trgt_table)
if (comment_exists) then
  ddl_str = ddl_str..'\n'..comment_str  
end

-- ##### Return results
summary = {}
summary[1] = {ddl_str}
return summary, "DDL varchar(2000000)"
/

-- Example:

-- execute script exa_toolbox.create_table_ddl('RETAIL', 'ARTICLE', 'RETAIL_COPY', 'ARTICLE_COPY', true);
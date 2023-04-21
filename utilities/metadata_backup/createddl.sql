execute script exa_toolbox.CREATE_DB_DDL(true,true,true);
export (select ddl from DB_HISTORY.DATABASE_DDL where backup_time = (select max(backup_time) from DB_HISTORY.DATABASE_DDL) order by backup_time, rn)
  into local csv file 'ddl.sql' truncate delimit=never;
--drop schema if exists db_history cascade;

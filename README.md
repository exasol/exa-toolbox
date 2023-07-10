# exa-toolbox
###### Please note that this is an open source project which is *not officially supported* by Exasol. We will try to help you as much as possible, but can't guarantee anything since this is not an official Exasol product.

The EXA-toolbox is a collection of useful scripts and views that you can add to your Exasol installation. Copy the script [load_scripts_from_github.sql](load_scripts_from_github.sql) into the SQL-editor of your choice and execute it. This will automatically pull all the scripts in this repository to your database and create them.

# Table of Contents

- [JSON](json/README.md#json)
  * [JSON table script](json/README.md#json-table-script)
  * [JSON flattening script](json/README.md#json-flattening-script)
    + [How it works](json/README.md#how-it-works)
    + [Examples](json/README.md#examples)
    + [Behavior of the script](json/README.md#behavior-of-the-script)
    + [Limitations](json/README.md#limitations)
  * [json_value](json/README.md#json_value)
  * [isjson](json/README.md#isjson)
- [Geospatial functions](geospatial_functions/README.md#geospatial-functions)
  * [Generic geospatial functions](geospatial_functions/README.md#generic_geospatial_functions)
  * [ST_HaversineDistance](geospatial_functions/README.md#st_haversinedistance)
  * [ST_GeomFromGeoJSON](geospatial_functions/README.md#st_geomfromgeojson)
- [Microsoft SQL Server compatibility](sqlserver_compatibility/README.md#microsoft-sql-server-compatibility)
  * [CONVERT_TO_DATE](sqlserver_compatibility/README.md#CONVERT_TO_DATE)
  * [DATEADD](sqlserver_compatibility/README.md#DATEADD)
  * [DATEDIFF](sqlserver_compatibility/README.md#DATEDIFF)
  * [DATENAME](sqlserver_compatibility/README.md#DATENAME)
  * [DATEPART](sqlserver_compatibility/README.md#DATEPART)
  * [GETUTCDATE](sqlserver_compatibility/README.md#GETUTCDATE)
  * [NEWID](sqlserver_compatibility/README.md#NEWID)
  * [JSON_VALUE](json/README.md#json_value)
  * [ISJSON](json/README.md#isjson)
- [System views](system_views/README.md#system-views)
  * [SCHEMA_SIZES](system_views/README.md#schema_sizes)
  * [TABLE_SIZES_TOP_100](system_views/README.md#table_sizes_top_100)
  * [AUDITING_LONG_RUNNING_DML_LAST24HOURS](system_views/README.md#auditing_long_running_dml_last24hours)
  * [AUDITING_LONG_RUNNING_DQL_LAST24HOURS](system_views/README.md#auditing_long_running_dql_last24hours)
  * [PROFILE_OF_RUNNING_QUERIES](system_views/README.md#profile_of_running_queries)
  * [GENERAL_SYSTEM_INFO](system_views/README.md#general_system_info)
  * [SESSIONS](system_views/README.md#sessions)
  * [DB_SIZE_LAST_DAY](system_views/README.md#db_size_last_day)
  * [DB_SIZE_DAILY](system_views/README.md#db_size_daily)
- [Utilities](utilities/README.md#utilities)
  * [bucketfs_ls](utilities/README.md#bucketfs_ls)
  * [check_connectivity](utilities/README.md#check_connectivity)
  * [check_tcp_listener_connection](utilities/README.md#check_tcp_listener_connection) 
  * [upload_github_release_file_to_bucketfs](utilities/README.md#upload_github_release_file_to_bucketfs)
  * [language_info](utilities/README.md#language_info)
  * [number_of_cores](utilities/README.md#number_of_cores)
  * [pub2slack](utilities/README.md#pub2slack)
  * [database_warmup](utilities/README.md#database_warmup)
  * [session_watchdog](utilities/README.md#session_watchdog)
  * [ldap_sync](utilities/README.md#ldap_sync)
  * [create_table_ddl](utilities/README.md#create_table_ddl)
  * [create_view_ddl](utilities/README.md#create_view_ddl)
  * [create_db_ddl](utilities/README.md#create_db_ddl)
  * [3rdLevelStatistics](utilities/README.md#3rdLevelStatistics)
  * [Union_All_Optimization_-_generate_view](utilities/README.md#Union_All_Optimization_-_generate_view)
  * [open_transactions](utilities/README.md#open_transactions)
  * [confd_xmlrpc](utilities/README.md#confd_xmlrpc)
  * [importing_and_exporting_data_with_google_bigquery](utilities/README.md#importing_and_exporting_data_with_google_bigquery)
  * [metadata_backup](utilities/README.md#metadata_backup)
  * [ParallelConnectionsExample](utilities/README.md#ParallelConnectionsExample)
- [Preprocessing](preprocessing)


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
- [Microsoft SQL Server compatibility](sqlserver_compatibility/README.md#microsoft-sql-server-compatibility)
  * [convert_to_date](sqlserver_compatibility/README.md#convert_to_date)
  * [dateadd](sqlserver_compatibility/README.md#dateadd)
  * [datediff](sqlserver_compatibility/README.md#datediff)
  * [datename](sqlserver_compatibility/README.md#datename)
  * [datepart](sqlserver_compatibility/README.md#datepart)
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
  * [language_info](utilities/README.md#language_info)
  * [pub2slack](utilities/README.md#pub2slack)
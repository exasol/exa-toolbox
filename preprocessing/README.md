# Table of Contents
- [Preprocessing](#preprocessing)
  * [How to use the SQL Preprocessor](#How)
  * [Teradata](#Teradata)

Exasol provides an [SQL Preprocessor](https://docs.exasol.com/database_concepts/sql_preprocessor.htm) that can preprocess all executed SQL statements. Using the preprocessor, unsupported SQL constructs can be transformed into existing SQL features (see examples below). Additionally, you can introduce syntactic sugar by replacing simple constructs with more complex elements.

### How to use the [SQL Preprocessor](https://docs.exasol.com/database_concepts/sql_preprocessor.htm)
Each preprocessor comes in the form of two scripts. A wrapper script and a transformation script. The latter contains the transformations that are applied to the SQL statements used. The wrapper script is responsible for calling the transformations and thus provides the functionalities.

##### How to get preprocessor scripts into the database
Select the appropriate script for your database from the repository and execute the SQL statements in your SQL client on the connection to Exasol. The scripts are pre-parameterized with the schema 'preprocessing'. The schema can of course be customized, but should be consistent across all parts of the preprocessor script.

##### How to enable/disable the preprocessor
If a preprosessor and which preprocessor is used is a session- or system parameter of the database. To enable a preprocessor for the current session only type:
`alter session set SQL_PREPROCESSOR_SCRIPT = <schema.script.sql>;` 
where the script location could be `PREPROCESSING.TeradataPre`. Since **every** SQL statement is now paresed through the preprocessor you might want to disable it at some point. To disable the preprocessor simply type:
`alter session set SQL_PREPROCESSOR_SCRIPT = '';`. Session parameters take effect immidiately.

If you want to enable the preprocessor system wide instead of the session parameter you can set the system paramter like this:
`alter system set SQL_PREPROCESSOR_SCRIPT = <schema.script.sql>;` 
For this to take effect you have to reconnect to the database.


## Teradata 
([teradata](teradata scripts))
The Teradata preprocessor scripts currently allow the following translations:

| Teradata | Translation in Exasol |
|---|---|
|LIKE ALL```[...] WHERE COL1 LIKE ALL('%house%', '%winter%')``` | ```[...] WHERE (COL1 LIKE '%house%' AND COL1 LIKE '%winter%')``` |
| LIKE ANY```[...] WHERE COL1 LIKE ANY('%house%', '%winter%')``` | ```[...] WHERE (COL1 LIKE '%house%' OR COL1 LIKE '%winter%')``` |
| ALL/ANY Combinations```[...] WHERE COL1 LIKE ALL('A', 'B') AND COL2 LIKE ANY('C', 'D')``` | ```[...] WHERE (COL1 LIKE 'A' AND COL1 LIKE 'B') AND (COL2 LIKE 'C' OR 'D')``` |
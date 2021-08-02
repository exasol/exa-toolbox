# Since Exasol v7.0 please use the native JSON functionality
https://docs.exasol.com/sql_references/functions/json.htm

# Table of Contents



<!-- toc -->

- [JSON](#json)
  * [JSON flattening script](#json-flattening-script)
    + [How it works](#how-it-works)
    + [Examples](#examples)
    + [Behavior of the script](#behavior-of-the-script)
    + [Limitations](#limitations)

<!-- tocstop -->

# JSON

## JSON flattening script

[flatten_json.sql](flatten_json.sql)

 This file contains a Lua script that is used to flatten JSON strings found in a `VARCHAR` column of an Exasol table.

The script's goal is to flatten a nested JSON string to create columns matching the corresponding fields of the JSON object and insert the matching values into a result table.

```sql
CREATE OR REPLACE LUA SCRIPT flat_json_table (
    json_table_schema, 
    json_table_name, 
    json_column, 
    result_table_schema, 
    result_table_name,
    flatten_array, 
    flatten_depth 
)  RETURNS TABLE AS
-- Beginning of script
...
```
The script parameters are : 
* The name of the schema containing the JSON table
* The name of the JSON table
* The name of the column containing the JSON strings
* The name of the schema containing the result table
* The name of the result table (the table containing the data of the flattened JSON)
* A boolean value to specify if the arrays/lists found within the JSON strings should also be flattened
* A integer value to specify the desired depth of the flattening, use `-1` if you want to completely flatten the JSON

### How it works
The Lua script called `FLAT_JSON_TABLE` uses two Python UDFs to create/alter the result table and insert the data into this table.
- The first is called `GET_COLUMNS` and is used to emit the column names and column types resulting from the flattening of the JSON strings found in the JSON column.
- The second is called `GET_DATA` and is used to emit the values of the flattened dictionaries.

Both UDFs use the same Python functions (logic of the flattening) to flatten the JSONs. These functions are found in a "class" UDF called `FLATTEN_JSON`. The main Python function within this "class" is called `flatten_json`. This function takes as input one JSON string and returns a flat Python dictionary corresponding to the JSON string flattened to the desired depth.
The two UDFs `GET_COLUMNS` and `GET_DATA` will call this function for each JSON string of the JSON column.

### Examples
```sql
CREATE OR REPLACE TABLE json_table(json_column VARCHAR(2000000));

INSERT INTO json_table VALUES 
('{"id":1,
   "first_name":"Mark",
   "last_name":"Trenaman",
   "info":{
       "phone":"573-411-0171",
       "city":"Washington",
       "hobbies":["sport", "music", "reading"]
       }
   }'),
('{"id":2,"first_name":"Lisa","last_name":"Kemer","info":{"phone":"601-112-0724","city":"Berlin", "hobbies":["dancing", "cooking"]}}'),
('{"id":3,"first_name":"Hannah","last_name":"Markson","info":{"phone":"481-964-5622","city":"Paris", "hobbies":["tech", "movies", "football"]}}');

DROP TABLE IF EXISTS result_table;

EXECUTE SCRIPT flat_json_table(
    'JSON_FLATTENING', 
    'JSON_TABLE',
    'JSON_COLUMN',
    'JSON_FLATTENING',
    'RESULT_TABLE',
    true,
    -1
);
```
- If you call the script by using the above parameters, the JSON strings will be completely flatten, and the arrays will also be flattened.
The result will be the following table : 

|FIRST_NAME| ID |INFO_CITY      |INFO_HOBBIES_0 |INFO_HOBBIES_1|INFO_HOBBIES_2|INFO_PHONE    |LAST_NAME |
|----------|----|---------------|---------------|--------------|--------------|--------------|----------|
|Mark      | 1  | Washington    | sport         | music        | reading      | 573-411-0171 | Trenaman |
|Lisa      | 2  | Berlin        | dancing       | cooking      |              | 601-112-0724 | Kemer    |
|Hannah    | 3  | Paris         | tech          | movies       | football     | 481-964-5622 | Markson  |


- If you want to keep the arrays/lists in the database, you can call the script like so : 
```sql
EXECUTE SCRIPT flat_json_table(
    'JSON_FLATTENING', 
    'JSON_TABLE',
    'JSON_COLUMN',
    'JSON_FLATTENING',
    'RESULT_TABLE',
    false, -- Here by specifying false, the list are not flattened
    -1
);
```
The results are the following table : 

|FIRST_NAME | ID | INFO_CITY     |INFO_HOBBIES                    |INFO_PHONE    |LAST_NAME |
|-----------|----|---------------|--------------------------------|--------------|----------|
|Mark       | 1  | Washington    | ["sport", "music", "reading"]  | 573-411-0171 | Trenaman |
|Lisa       | 2  | Berlin        | ["dancing", "cooking"]         | 601-112-0724 | Kemer    |
|Hannah     | 3  | Paris         | ["tech", "movies", "football"] | 481-964-5622 | Markson  |

- If you only want to flatten the json strings with a depth of 1, you can call the script like so : 
```sql
EXECUTE SCRIPT flat_json_table(
    'JSON_FLATTENING', 
    'JSON_TABLE',
    'JSON_COLUMN',
    'JSON_FLATTENING',
    'RESULT_TABLE',
    true, -- true/false doesn't matter in this case as there are no list at the depth of 1
    1     -- Here by specifying 1 the script only flattens the JSON string one level
);
```
The results are the following table : 

|FIRST_NAME|ID  |INFO|LAST_NAME |
|----------|----|-------------------------------------------------------------------------------------------|----------|
|Mark      | 1  | {"phone": "573-411-0171", "hobbies": ["sport", "music", "reading"], "city": "Washington"} | Trenaman |
|Lisa      | 2  | {"phone": "601-112-0724", "hobbies": ["dancing", "cooking"], "city": "Berlin"}            | Kemer    |
|Hannah    | 3  | {"phone": "481-964-5622", "hobbies": ["tech", "movies", "football"], "city": "Paris"}     | Markson  |


### Behavior of the script
The script deals with two types of JSON strings, and it deals with them differently.
- The JSON string is of type `list`, this means the file is of the following structure: `[{...}, {...}, {...}]`.
  In this case, the script will create one row per subdictionary flattened. So one JSON value in the JSON column can create multiple rows. For the script to work, the subdictionaries (`{...}`) within the same list/JSON need to be of the same structure (have the same fields/keys).
- The JSON string is of type `dict`, this means the file is of the following structure: `{{...}, {...}, {...}}`.
  In this case, the script will create only one row per JSON value in the JSON column as the result of the flattening will be one flat dictionary. 

For better understanding, you can find one example of each case in the `flatten_json.sql` file. 

### Limitations
If multiple JSON values in the JSON column have the same fields (keys) but the corresponding values are not always of the same datatype, the script will have already created a column with the first value and the matching datatype, so when trying to insert a value in the table with a different datatype, the script will break. 
There is a workaround to avoid breaking the insertion of the data which is to convert all of the fields datatypes of the JSON values to strings. To do so you can find the following piece of code in the `flatten_json` function of the `flatten_json` UDF/class : 

```python
def flatten_json(my_json, depth=-1, flatten_array=False):
    '''
    # By uncommenting the following lines, all of the values/fields from the json file will be converted to string
    #this allows the user to import data from multiple json files even if the same columns/keys found within the different files do not have the same datatypes
    my_json=convertToString(my_json)
    '''
    ...

```
You just need to uncomment these lines and re-execute the `flatten_json.sql` file to replace the scripts.
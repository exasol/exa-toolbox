create schema if not exists EXA_TOOLBOX;

/*
This python script contains the pynthon functions which will be used to flatten the JSON files
It acts as a "class" or "library" that will be imported in other python scripts 
The main function is the json_flatten function which will call the other functions when needed
*/ 
--/
create or replace python scalar script EXA_TOOLBOX.JSON_FLATTEN()
returns double
as

from collections import defaultdict

'''
This function is used to convert python datatypes to exasol types
It is used to create the columns used in the "create table" and "insert into" statements  
'''
def convertType(columnType):
        exaType = 'varchar(2000000)'
        if columnType is int:
                exaType = 'decimal(18,0)'
        elif columnType is float:
                exaType = 'double precision'
        elif columnType is bool:
                exaType = 'bool'
        return exaType


'''
This function is used to convert all of the json fields to strings inside python
'''
def convertToString(obj):
    if isinstance(obj, bool):
        return unicode(str(obj).lower(), "utf-8")
    if isinstance(obj, int) or isinstance(obj, float) or isinstance(obj, long):
        return unicode(str(obj), "utf-8")
    if isinstance(obj, (list, tuple)):
        return [convertToString(item) for item in obj]
    if isinstance(obj, dict):
        return {convertToString(key):convertToString(value) for key, value in obj.items()}
    return obj

'''
This recursive function is used to completely flatten the json/dict object passed as a parameter (full depth)
The flatten_array parameter is used to specify if the lists/arrays found inside the json object should be flatenned too
This function returns a python dictonnary containing the fields/columns of the json object flattened as keys and their corresponding values
'''
def flatten_json_rec(my_json, flatten_array=True):
        out = {}
    
        def flatten(x, name=''):

                if type(x) is dict:
                        for a in x:
                                flatten(x[a], name + a + '_')
                elif type(x) is list and flatten_array:
                        i = 0
                        for a in x:
                                flatten(a, name + str(i) + '_')
                                i += 1
                else:
                        out[name[:-1]] = x

        flatten(my_json)
        return out
        
'''
This function takes a key and a value from a parent dictionnary as parameter
It returns a dict flatten once if the value passed as a parameter is also a dict
It returns a dict flatten once if the value passed as a parameter is a list and if the flatten_array boolean is true
It returns the pair as a dict given as a parameter if the value is nor a dict nor a list
'''
def flatten_dict(key, value, flatten_array=False):
        res = {}
        if type(value) is dict:
                for subkey in value:
                        new_key = key + "_" + subkey
                        new_value = value[subkey]
                        res[new_key] = new_value
        elif type(value) is list and flatten_array:
                for index, element in enumerate(value):
                        new_key = key + "_" + str(index)
                        new_value = element
                        res[new_key] = new_value
        else:
                res[key] = value
        return res
        
'''
This function will take a json field as a parameter and flatten it for one level of nested dictionnaries if it is a dict
It calls the function flatten_dict on each of the values of the dict given as a parameter and appends the result to a result dict
It returns a dict with the same field as the input dict but flattened once
'''
def flatten_dict_once(my_dict, flatten_array=False):
        res = {}
        if type(my_dict) is dict:
                for key in my_dict:
                        res_tmp = flatten_dict(key, my_dict[key], flatten_array)
                        res.update(res_tmp)
                return res
        else:
                return my_dict
        
'''
This function is the function called on the initial json object
It takes as parameter the json object, the depth and the boolean to specify if we want arrays/lists to be flattened
This function will act two different ways depending on the type of the json object
If the json object is of type dict, this function will flatten it to the depth specified and return a dict (flattened json) where each key (column name) only has one value 
(in this case, the table that will be created using the output of this function will have one row per json file)
If the json object is of type list, this function expect the json to contains subdicts of the same format : it will thus flatten each subdict to the depth specified and return a dict where each key (column name) has a list as value with each subvalues (column)
(in this case, the table that will be created using the output of this function will have multiple row per json file)
This function returns a tuple containing the resulting flattened dict and the type of the input json
'''
def flatten_json(my_json, depth=-1, flatten_array=False):
        '''
        #by uncommenting the following lines, all of the values/fields from the json file will be converted to string
        #this allows the user to import data from multiple json files even if the same columns/keys found within the different files do not have the same datatypes
        my_json=convertToString(my_json)
        '''
        if type(my_json) is dict:
                if depth == -1:
                        return (flatten_json_rec(my_json, flatten_array), "dict")
                elif depth > 0:
                        res = my_json
                        for i in range(1, depth):
                                res = flatten_dict_once(res, flatten_array)
                        return (res, "dict")
                else:
                        return (my_json, "dict")
                        
	#case of a json files that contains multiple dict with the same fieds
	elif type(my_json) is list:
		listDict = []
		for value in my_json:
			tmpDict, _ = flatten_json(value, depth, flatten_array)
			listDict.append(tmpDict)
		res = defaultdict(list)
		for d in listDict: 
			for key, value in d.iteritems():
   				res[key].append(value)
   		return (res, "list")
	else:
		print('input not of type "dict or list"')
                        

/

/*
This python script takes as parameter a json file as a string, a boolean that specify if we want to flatten arrays/lists, and a depth for the flattening
This script will call the flatten_json python function on the json object
It will emit the column name and column type of each column of the flattened json "flat" (corresponds to the keys of the result dict/flattened json)
*/
--/
create or replace python scalar script EXA_TOOLBOX.JSON_FLATTEN_GET_COLUMNS("INPUT" varchar(2000000), flatten_array bool, flatten_depth decimal(18,0)) 
emits (columnName varchar(10000), columnType varchar(10000)) as
import json
FLATTENING = exa.import_script("EXA_TOOLBOX.JSON_FLATTEN")

def run(ctx):
        my_data = json.loads(ctx.INPUT)
        flat, jsonType = FLATTENING.flatten_json(my_data, ctx.flatten_depth, ctx.flatten_array)
        
        if(jsonType=="dict"):                 
                for key in sorted(flat.iterkeys()):
                        columnName = str(key)
                        columnType = FLATTENING.convertType(type(flat[key]))
                        ctx.emit(columnName, columnType)
        elif(jsonType=="list"):
                for key in sorted(flat.iterkeys()):
                        columnName = str(key)
                        columnType = FLATTENING.convertType(type(flat[key][0]))
                        ctx.emit(columnName, columnType)
/


/*
This python script takes as parameter a json file as a string, a boolean that specify if we want to flatten arrays/lists, and a depth for the flattening
This script will call the flatten_json python function on the json object
It will emit the values found in the result dict/flattened json "flat" for each column
If the json was of type "list", this script will emit multiple rows found in the result dict/flattened json "flat"
*/
--/
create or replace python scalar script EXA_TOOLBOX.GET_DATA("INPUT" varchar(2000000), flatten_array bool, flatten_depth decimal(18,0), columns varchar(2000000)) 
emits (...) as
import json
from collections import OrderedDict
FLATTENING = exa.import_script("EXA_TOOLBOX.JSON_FLATTEN")

def run(ctx):
        my_data = json.loads(ctx.INPUT)
        flat, jsonType = FLATTENING.flatten_json(my_data, ctx.flatten_depth, ctx.flatten_array)
        
        cols = OrderedDict()
        colsStr = ctx.columns.upper()
                        
        if(jsonType=="dict"):
                currentRow = []
                for col in colsStr.split(','):
                        cols[col]=None
                for key in sorted(flat.iterkeys()):
                        if type(flat[key]) is list or type(flat[key]) is dict:
                                str1 = json.dumps(flat[key])
                                cols[key.upper()] = str1
                        else:
                                cols[key.upper()] = flat[key]

                currentRow = cols.values()
                ctx.emit(*currentRow)
                
        elif(jsonType=="list"):
                nbRows = len(flat.values()[0])
                for index in range(0, nbRows):
                        currentRow = []
                        for col in colsStr.split(','):
                                cols[col]=None
                        for key in sorted(flat.iterkeys()):
                                tmpList = flat[key]
                                element = tmpList[index]
                                if type(element) is list or type(element) is dict:
                                        str1 = json.dumps(element)
                                        cols[key.upper()] = str1
                                else:
                                        cols[key.upper()] = element
                        currentRow = cols.values()
                        ctx.emit(*currentRow)

/


/*
This lua script takes as parameter a json_table containing the json files, a result table where we want to insert the data
The user has to specify the name of the column in the json_table where the json strings are
It also takes a boolean to specify if we want to flatten arrays/lists and a integer to specify the depth of the flattening
This script will call the pythons script "get_columns" and "get_data" to create or alter the result table and insert the corresponding data
*/
--/
create or replace lua script EXA_TOOLBOX.FLAT_JSON_TABLE(
json_table_schema, 
json_table_name, --the table containing the json strings (files)
json_column, --the column containing the json strings (files)
result_table_schema, 
result_table_name, --the flat table you want to get after flattening the jsons
flatten_array, -- boolean value : if true, script will flatten lists/arrays, if false list will be left as is
flatten_depth -- integer value to specify the depth of the flattening, to flatten completely use -1
) 
returns table as

                     
--get the columns from each json value
suc, cols = pquery([[
                    select distinct COLUMNNAME, COLUMNTYPE from (
                    select EXA_TOOLBOX.JSON_FLATTEN_GET_COLUMNS (]]..json_column..[[, :fl, :fd)
                    from ]]..json_table_schema..[[.]]..json_table_name..[[
                    )
                    order by COLUMNNAME;
                    ]], {fl = flatten_array, fd = flatten_depth})
--check if result table already exists
suc, checkExist = pquery([[describe ]]..result_table_schema..[[.]] .. result_table_name .. [[;]], {})

if suc then -- table already exists
        for j=1, #cols do
                --add column if it doesn't exist
                suc, addCol = pquery([[alter table ]]..result_table_schema..[[.]] .. result_table_name .. [[ add column if not exists (]]..cols[j][1]..[[ ]]..cols[j][2]..[[);]], {})
        end
else --table does not exists, we create it
        local query = "create table " .. result_table_schema .. "." .. result_table_name .. "("
        for j=1, #cols-1 do
                query = query ..'"'.. tostring(cols[j][1]) .. '" ' .. tostring(cols[j][2]) .. ', '
        end
        query = query ..'"'.. tostring(cols[#cols][1]) .. '" ' .. tostring(cols[#cols][2]) .. ');'
        -- execute the 'create table' statement
        
        suc, createTable = pquery([[]]..query..[[]],{})
end

-- get all the column names from the created/altered table
suc, colNames = pquery([[
                        select group_concat(COLUMN_NAME order by COLUMN_ORDINAL_POSITION) from SYS.EXA_ALL_COLUMNS
                        where COLUMN_TABLE = :table
                        and COLUMN_SCHEMA = :schema;
                        ]],{table = result_table_name, schema = result_table_schema})
                        
-- insert the data into the result table
suc, ins = pquery([[
                  insert into ]]..result_table_schema..[[.]]..result_table_name..[[ 
                  select GET_DATA(]]..json_column..[[, :fl, :fd, :cols)
                  from ]]..json_table_schema..[[.]]..json_table_name..[[;
                  ]],{fl = flatten_array, fd = flatten_depth, cols=colNames[1][1]}) 

if not suc then
        error('"'..ins.error_message..'" Caught while inserting the data using the script GET_DATA: "'..ins.statement_text..'"')
end 

suc, res = pquery([[select * from ]]..result_table_schema..[[.]]..result_table_name..[[ limit 100;]],{})

return(res)

/


----------------------------------EXAMPLE_OF_SCRIPT_EXECUTION---------------------------------------------------------------

create or replace table EXA_TOOLBOX.MOCK_TABLE (JSON varchar(2000000));
insert into EXA_TOOLBOX.MOCK_TABLE values (
'
[
    {
        "Name": "Debian",
        "Version": {
            "Newest" : "9",
            "Former": "8",
            "Oldest": "6"
        },
        "Install": "apt",
        "Owner": "SPI",
        "Kernel": "4.9"
    },
    {
        "Name": "Ubuntu",
        "Version": {
            "Newest": "17.10",
            "Former": "16.10",
            "Oldest": "14.10"
        },
        "Install": "apt",
        "Owner": "Canonical",
        "Kernel": "4.13"
    },
    {
        "Name": "Fedora",
        "Version": {
            "Newest": "26",
            "Former": "24",
            "Oldest": "22"
        },
        "Install": "dnf",
        "Owner": "Red Hat",
        "Kernel": "4.13"
    },
    {
        "Name": "CentOS",
        "Version": {
            "Newest" : "7",
            "Former": "5",
            "Oldest": "3"
        },
        "Install": "yum",
        "Owner": "Red Hat",
        "Kernel": "3.10"
    },
    {
        "Name": "OpenSUSE",
        "Version": {
            "Newest": "42.3",
            "Former": "42.2",
            "Oldest": "42.1"
        },
        "Install": "zypper",
        "Owner": "Novell",
        "Kernel": "4.4"
    },
    {
        "Name": "Arch Linux",
        "Version": {
            "Newest" : "Rolling Release",
            "Former": "Former Release",
            "Oldest":"Oldest Release"
        },
        "Install": "pacman",
        "Owner": "SPI",
        "Kernel": "4.13"
    },
    {
        "Name": "Gentoo",
        "Version": {
            "Newest" : "Rolling Release",
            "Former": "Former Release",
            "Oldest":"Oldest Release"
        },  
        "Install": "emerge",
        "Owner": "Gentoo Foundation",   
        "Kernel": "4.12"
    }
]
'
);

drop table if exists EXA_TOOLBOX.RESULT_TABLE;
execute script EXA_TOOLBOX.FLAT_JSON_TABLE('EXA_TOOLBOX', 'MOCK_TABLE', 'JSON', 'EXA_TOOLBOX', 'RESULT_TABLE', true, -1);

create or replace table EXA_TOOLBOX.JSON_TABLE(JSON_COLUMN varchar(2000000));
insert into EXA_TOOLBOX.JSON_TABLE values 
('{"id":1,"first_name":"Mark","last_name":"Trenaman","info":{"phone":"573-411-0171","city":"Washington", "hobbies":["sport", "music", "reading"]}}'),
('{"id":2,"first_name":"Lisa","last_name":"Kemer","info":{"phone":"601-112-0724","city":"Berlin", "hobbies":["dancing", "cooking"]}}'),
('{"id":3,"first_name":"Hannah","last_name":"Markson","info":{"phone":"481-964-5622","city":"Paris", "hobbies":["tech", "movies", "football"]}}');

drop table if exists EXA_TOOLBOX.RESULT_TABLE;
execute script EXA_TOOLBOX.FLAT_JSON_TABLE('EXA_TOOLBOX', 'JSON_TABLE', 'JSON_COLUMN', 'EXA_TOOLBOX', 'RESULT_TABLE', true, -1);
drop table if exists EXA_TOOLBOX.RESULT_TABLE;
execute script EXA_TOOLBOX.FLAT_JSON_TABLE('EXA_TOOLBOX', 'JSON_TABLE', 'JSON_COLUMN', 'EXA_TOOLBOX', 'RESULT_TABLE', false, -1);
drop table if exists EXA_TOOLBOX.RESULT_TABLE;
execute script EXA_TOOLBOX.FLAT_JSON_TABLE('EXA_TOOLBOX', 'JSON_TABLE', 'JSON_COLUMN', 'EXA_TOOLBOX', 'RESULT_TABLE', false, 1);
drop table if exists EXA_TOOLBOX.RESULT_TABLE;

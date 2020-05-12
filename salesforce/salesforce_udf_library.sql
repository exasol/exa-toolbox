/* Please modify these the following lines accordingly. */
CREATE OR REPLACE CONNECTION SF_DEMO_PASSWORD TO '' USER '<my_name>@<my_company>.com' IDENTIFIED BY '<my_salesforce_password>';
CREATE OR REPLACE CONNECTION SF_DEMO_SECURITY_TOKEN TO '' IDENTIFIED BY '<my_salesforce_security_token>';

GRANT ACCESS ON CONNECTION SF_DEMO_PASSWORD TO <my_database_user>;
GRANT ACCESS ON CONNECTION SF_DEMO_SECURITY_TOKEN TO <my_database_user>;


/*
        This function is used as a library for the other UDFs.
        This way, common code does not need to be duplicated.
        This function is not intended to be called directly. However, if you wish to do so,
        you can remove sf_object_type as input parameter from the run() and default_output_columns()
        functions and use the commented global variable sf_object_type directly instead.
*/
--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT "GET_FROM_SALESFORCE" ()
EMITS (...) AS


import requests
from simple_salesforce import Salesforce
import json
import pandas as pd
import numpy as np
import collections #-- for converting OrderedDict to String
from datetime import datetime, timedelta, timezone #--for datetime calculations

#-- get data from connections
username = exa.get_connection('SF_DEMO_PASSWORD').user
password = exa.get_connection('SF_DEMO_PASSWORD').password
security_token = exa.get_connection('SF_DEMO_SECURITY_TOKEN').password

#-- Global variables
sf = None
fields = None
data_type_df = None
#-- uncomment the following line if you want to call get_from_salesforce directly
#--sf_object_type = 'Account'


#-- HELPER FUNCTIONS
def getFields(sf_object_type):
    global sf
    if sf == None:
        sf = Salesforce(username=username, password=password, security_token=security_token)
    
    if sf_object_type == 'Contact':
        desc = sf.Contact.describe()
    elif sf_object_type == 'Account':
        desc = sf.Account.describe()
    elif sf_object_type == 'Opportunity':
        desc = sf.Opportunity.describe()
    else:
        raise Exception('The type {} is not implemented yet, please add in the section of getFileds'.format(sf_object_type))
        
    return desc['fields']
    
#------   

#-- gets datatype definitions for the corresponding salesforce object
def get_type_dataframe(sf_object_type):
    global fields
    #-- map Salesforce types to Exasol types    
    type_dict ={
        "boolean": "BOOLEAN",
        "int": "DECIMAL(32,0)",
        "double": "DOUBLE",
        "datetime": "TIMESTAMP",
        "date": "DATE",
        "currency": "DECIMAL(32,2)",
        "percent": "DECIMAL(3,0)"
    } 
    default_value = 'VARCHAR'
    
    
    #-- build connection to salesforce and get metadata
    if (fields == None):
        fields = getFields(sf_object_type)
    type_df = pd.DataFrame(fields)
    type_df = type_df.filter(items=['name', 'label', 'length', 'precision', 'type'])
    
    #-- map salesforce datatypes to dabase datatype
    type_df['db_type'] = type_df.type.map(type_dict).fillna(default_value)
    type_df['db_type_full'] = type_df['db_type']
    type_df['db_type_full'] = np.where((type_df.db_type == 'DECIMAL'),type_df.db_type + '(' + type_df.length.map(str) + ',' + type_df.precision.map(str)+')', type_df.db_type_full)
    type_df['db_type_full'] = np.where((type_df.db_type == 'DOUBLE'),'DECIMAL' + '(' + type_df.precision.map(str) + ',' + type_df.length.map(str)+')', type_df.db_type_full)
    type_df['db_type_full'] = np.where((~type_df.db_type.isin(list(type_dict.values()))),type_df.db_type + '(' + type_df.length.map(str) + ')', type_df.db_type_full)
    # replace VARCHAR(0) with somethig bigger
    type_df.db_type_full.replace('VARCHAR(0)', 'VARCHAR(2000)', inplace=True)
    return type_df
#------

def date_to_iso8601(date):
    """Returns an ISO8601 string from a date"""
    datetimestr = date.strftime('%Y-%m-%dT%H:%M:%S')
    timezone_sign = date.strftime('%z')[0:1]
    timezone_str = '%s:%s' % (
        date.strftime('%z')[1:3],
        date.strftime('%z')[3:5],
    )
    return (
        '{datetimestr}{tzsign}{timezone}'.format(
            datetimestr=datetimestr, tzsign=timezone_sign, timezone=timezone_str
        )
    )
#------
#-- END HELPER FUNCTIONS

#-- RUN FUNCTION
def run(ctx, sf_object_type):
    #-- tell the script to use the global versions of these variables instead of creating local ones
    global sf
    global fields
    global data_type_df
    
    
    #-- Only executes the function, if data_type_df is not yet initialized
    if(data_type_df  == None):
        data_type_df = get_type_dataframe(sf_object_type)
    if (fields == None):
        fields = getFields(sf_object_type)  
    
    

    field_names = [field['name'] for field in fields]
    soql = "SELECT {} FROM {}".format(','.join(field_names), sf_object_type)
    
    # -- option with time filter:
    # --dt = datetime.now().astimezone() -timedelta(days=14)
    # --soql = "SELECT {} FROM {} WHERE LastModifiedDate > {}".format(','.join(field_names), sf_object_type, date_to_iso8601(dt))
    
    #-- build connection to salesforce and get metadata
    if sf == None:
        sf = Salesforce(username=username, password=password, security_token=security_token)
    sf_data = sf.query_all(soql)
    
    sf_df = pd.DataFrame(sf_data['records'])
    #-- if no data is returned, exit the UDF
    if(sf_df.empty):
        return
        
    sf_df = sf_df.drop(columns='attributes')   
    
    #-- Work on the resulting dataset:
    #-- convert OrderedDict to String
    def get_dict(d):
        if not isinstance(d, collections.OrderedDict):
            return d
        if d is None:
            return None
        return ",".join(["{}={}".format(k, v) for k, v in d.items()])
    sf_df = sf_df.applymap(get_dict)
    
    #-- convert Timestamp cols to Timestamp
    timestamp_cols = data_type_df.index[data_type_df['db_type'] == 'TIMESTAMP'].tolist()
    sf_df.iloc[:,timestamp_cols] = sf_df.iloc[:,timestamp_cols].apply(pd.to_datetime) 
    
    #-- convert Date cols to Date
    def conv_date(x):
        if x == None:
            return None
        return pd.to_datetime(x).date()

    date_cols = data_type_df.index[data_type_df['db_type'] == 'DATE'].tolist()
    sf_df.iloc[:,date_cols] = sf_df.iloc[:,date_cols].applymap(conv_date)
     
    ctx.emit(sf_df)
    
#-- END RUN FUNCTION
#-------------------------

#-- OUTPUT COLUMN FUNCTION
#-- Exasol function that determines the datatypes for the EMIT
#-- This way, they don't need to be specified manually
#-- This function is called before the run function and therefore does not know the context variable yet
def default_output_columns(sf_object_type):
    global data_type_df
    #-- Only executes function, if data_type_df is not yet initialized
    if(data_type_df == None):
        data_type_df = get_type_dataframe(sf_object_type)
    
    output_args = '"' + data_type_df.name + '" ' + data_type_df.db_type_full
    return (", ".join(output_args))
#-- END OUTPUT COLUMN FUNCTION     
/

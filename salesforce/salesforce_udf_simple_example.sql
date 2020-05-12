/**

Purpose: 
- Connect to Salesforce API
- Load Data from Salesforce

**/


--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT "SALESFORCE_UDF" (username VARCHAR(100), password VARCHAR(100), security_token VARCHAR(100))
EMITS ("Name" varchar(2000), "Email" varchar(2000)) AS

import glob
sys.path.extend(glob.glob('/buckets/bucketfs1/demo_salesforce/*'))

import requests
from simple_salesforce import Salesforce
import json
import pandas as pd


def run(ctx):
    sf = Salesforce(username=ctx.username, password=ctx.password, security_token=ctx.security_token)

    sf_data = sf.query_all("SELECT name, email FROM Contact")    
    sf_df = pd.DataFrame(sf_data['records']).drop(columns='attributes')    
    ctx.emit(sf_df)
    
/


create or replace table sf_credentials(username VARCHAR(100), password VARCHAR(100), security_token VARCHAR(100));
-- change the following line
insert into sf_credentials values ('<my_email>', '<my_password>','<my_security_token>');


select salesforce_udf(username, password, security_token) 
from sf_credentials;

create or replace table contacts as
(
select salesforce_udf(username, password, security_token) 
from sf_credentials
);

select * from contacts;



-- Check the content of the bucket, it should contain:
-- Authlib-0.14.1-py2.py3-none-any.whl*
-- simple_salesforce-1.0.0-py2.py3-none-any.whl*
--SELECT exa_toolbox.bucketfs_ls('/buckets/bucketfs1/demo_salesforce');
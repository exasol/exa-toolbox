/*
        This file contains the actual implementations for different salesforce object types.
        Please create the function GET_FROM_SALESFORCE in the other file before using these ones.
        Adapt the paths in the lines containing 
        sys.path.extend(glob.glob('/buckets/bucketfs1/demo_salesforce/*'))
        matching your bucketfs setup.
        Feel free to create functions for other types of salesforce objects you need.
        Therefore, just adapt the UDF's name and the line defining 'sf_object_type'.
*/

--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT "GET_ACCOUNTS_FROM_SALESFORCE" ()
EMITS (...) AS

import glob
sys.path.extend(glob.glob('/buckets/bucketfs1/demo_salesforce/*'))
sf_lib = exa.import_script('GET_FROM_SALESFORCE')

sf_object_type = 'Account' 

def run(ctx):
    return sf_lib.run(ctx, sf_object_type)
        
def default_output_columns():
   return sf_lib.default_output_columns(sf_object_type)
/

select get_accounts_from_salesforce();


--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT "GET_OPPORTUNITIES_FROM_SALESFORCE" ()
EMITS (...) AS

import glob
sys.path.extend(glob.glob('/buckets/bucketfs1/demo_salesforce/*'))
sf_lib = exa.import_script('GET_FROM_SALESFORCE')

sf_object_type = 'Opportunity' 

def run(ctx):
    return sf_lib.run(ctx, sf_object_type)
        
def default_output_columns():
   return sf_lib.default_output_columns(sf_object_type)
/

-- Calling the Salesforce UDF to get all Opportunities
select GET_OPPORTUNITIES_FROM_SALESFORCE();


-- Using two UDFs at once
with accounts as (
select GET_ACCOUNTS_FROM_SALESFORCE()),
opportunities as (
select GET_OPPORTUNITIES_FROM_SALESFORCE()
)
select o."Name", o."ExpectedRevenue", a."Name", a."Industry"
from accounts a, opportunities o
where o."AccountId" = a."Id";


-- Using two UDFs and analytical function on top
with accounts as (
select GET_ACCOUNTS_FROM_SALESFORCE()),
opportunities as (
select GET_OPPORTUNITIES_FROM_SALESFORCE()
)
select  a."Industry", 
        sum(o."ExpectedRevenue") as "ExpectedOpportunityRevenue", 
        round(sum(o."ExpectedRevenue") / sum(sum(o."ExpectedRevenue")) over() * 100 ,2) as "Percentage"
from accounts a, opportunities o
where o."AccountId" = a."Id"
group by a."Industry"
order by local."Percentage" desc;


-- Persist Opportunity data into a table
create or replace table OPPORTUNITIES as 
(
select GET_OPPORTUNITIES_FROM_SALESFORCE()
);

select count(*) from OPPORTUNITIES;

-- Persist Account data into a table
create or replace table ACCOUNTS as 
(
select GET_ACCOUNTS_FROM_SALESFORCE()
);

select count(*) from ACCOUNTS;


-- Analytical query from above, now with persisted tables
select  a."Industry", 
        sum(o."ExpectedRevenue") as "ExpectedOpportunityRevenue", 
        round(sum(o."ExpectedRevenue") / sum(sum(o."ExpectedRevenue")) over() * 100 ,2) as "Percentage"
from accounts a, opportunities o
where o."AccountId" = a."Id"
group by a."Industry"
order by local."Percentage" desc;
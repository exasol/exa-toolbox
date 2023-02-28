/*
        The scripts to accelerate importing data from Bigquery to Exasol by means of using an intermediate CSV file.
        
        Originally mentioned in article https://exasol.my.site.com/s/article/Statistics-export-for-support?language=en_US
*/


-- The ALTER SESSION statement will enable the new script language container containing the bugquery python package
-- You should replace the ALTER SESSION with the link to your script language container, the below is just an example
-- Not needed since DB versions 7.0.17 and 7.1.7.
ALTER SESSION SET SCRIPT_LANGUAGES='PYTHON3=localzmq+protobuf:///bucketfs1/bq/standard-EXASOL-7.0.0_release?lang=python#buckets/bucketfs1/bq/standard-EXASOL-7.0.0_release/exaudf/exaudfclient_py3 PYTHON=localzmq+protobuf:///bucketfs1/bq/standard-EXASOL-7.0.0_release?lang=python#buckets/bucketfs1/bq/standard-EXASOL-7.0.0_release/exaudf/exaudfclient JAVA=localzmq+protobuf:///bucketfs1/bq/standard-EXASOL-7.0.0_release?lang=java#buckets/bucketfs1/bq/standard-EXASOL-7.0.0_release/exaudf/exaudfclient R=localzmq+protobuf:///bucketfs1/bq/standard-EXASOL-7.0.0_release?lang=r#buckets/bucketfs1/bq/standard-EXASOL-7.0.0_release/exaudf/exaudfclient';

create connection google_cloud_storage to 'https://<bucket_name>.storage.googleapis.com' user '<access key>' IDENTIFIED BY '<secret>';

CREATE SCHEMA ETL;
OPEN SCHEMA ETL;

--/
create or replace lua script ETL.bigquery_import (connection_name, file_name, bigquery_dataset, bigquery_table, exasol_schema , exasol_table) returns table as 
summary = {}
export_suc,export_res = pquery([[SELECT ETL.EXPORT_BIGQUERY_TO_CSV(:d,:t,:c,:f)]],{d=bigquery_dataset,t=bigquery_table,c=connection_name,f=file_name})
        
        if (export_suc) then
                summary[#summary+1] = {[[Bigquery Table ]]..bigquery_dataset..[[.]]..bigquery_table..[[ exported successfully to Google Cloud Storage]]}
                import_suc, import_res = pquery([[IMPORT INTO ::s.::t from CSV AT ::c FILE :f SKIP=1]],{s=exasol_schema,t=exasol_table,c=connection_name,f=file_name})
                if (import_suc) then
                        summary[#summary+1] = {[[File ]]..file_name..[[ imported successfully to Exasol table ]]..exasol_schema..[[.]]..exasol_table}
                else
                        error(import_res.error_message)
                end

        else
                error(export_res.error_message)
        end



return summary,"message varchar(200000)"
/

--/
create or replace python3 scalar script ETL.export_bigquery_to_csv (bigquery_dataset varchar(20000), bigquery_table varchar(20000), connection_name varchar(20000), file_name varchar(20000)) returns varchar(2000000) as

import sys
import glob

# the below line is only needed if you added the bigquery python libaries to bucketfs directly
# sys.path.extend(glob.glob('/buckets/<bucketfs_name>/<bucket_name>/*'))
from google.cloud import bigquery
from google.oauth2 import service_account
key_path = "buckets/<bucketfs_name>/<bucket_name>/<private_key>.json"
credentials = service_account.Credentials.from_service_account_file(key_path,scopes=["https://www.googleapis.com/auth/cloud-platform"])

client = bigquery.Client(credentials=credentials,project=credentials.project_id)


def run(ctx):
        connection_url = exa.get_connection(ctx.connection_name).address
        bucket_name = connection_url.split('.')
        bucket_name = bucket_name[0].split('//')
        bucket_name = bucket_name[1]
        
        project = credentials.project_id
        dataset_id = ctx.bigquery_dataset
        table_id = ctx.bigquery_table

        destination_uri = "gs://{}/{}".format(bucket_name, ctx.file_name)
        dataset_ref = bigquery.DatasetReference(project, dataset_id)
        table_ref = dataset_ref.table(table_id)

        extract_job = client.extract_table(
                table_ref,
                destination_uri,
                # Location must match that of the source table.
                location="US",
                )  # API request
        extract_job.result()  # Waits for job to complete.
        
/

execute script ETL.bigquery_import('GOOGLE_CLOUD_STORAGE','test_2.csv','NICO2','NICO3','TEST','NUMBERS');

truncate table test.numbers;

select COUNT(*) from test.numbers;
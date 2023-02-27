/*
        The scripts to accelerate exporting data to Bigquery from Exasol by means of using an intermediate CSV file.
        
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
create or replace lua script ETL.bigquery_export (connection_name, file_name, bigquery_dataset, bigquery_table, exasol_schema , exasol_table) returns table as 
summary = {}
export_suc, export_res = pquery([[EXPORT ::s.::t INTO CSV AT ::c FILE :f]],{s=exasol_schema,t=exasol_table,c=connection_name,f=file_name})

if (export_suc) then
        summary[#summary+1] = {[[Table ]]..exasol_schema..[[.]]..exasol_table..[[ exported successfully to Google Cloud Storage]]}
        
        import_suc,import_res = pquery([[SELECT ETL.IMPORT_CSV_TO_BIGQUERY(:d,:t,:c,:f)]],{d=bigquery_dataset,t=bigquery_table,c=connection_name,f=file_name})
        
        if (import_suc) then
                summary[#summary+1] = {[[File ]]..file_name..[[ imported successfully to bigquery table ]]..bigquery_table}
        else
                error(import_res.error_message)
        end
        
else
        error(export_res.error_message)
end

return summary,"message varchar(200000)"
/

--/
create or replace python3 scalar script ETL.import_csv_to_bigquery (bigquery_dataset varchar(20000), bigquery_table varchar(20000), connection_name varchar(20000), file_name varchar(20000)) returns varchar(2000000) as

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

        table_ref = client.dataset(ctx.bigquery_dataset).table(ctx.bigquery_table)
        job_config = bigquery.LoadJobConfig()
        job_config.write_disposition = bigquery.WriteDisposition.WRITE_APPEND
        job_config.skip_leading_rows = 0
        # The source format defaults to CSV, so the line below is optional.
        job_config.source_format = bigquery.SourceFormat.CSV
        uri = "gs://" + bucket_name + "/" + ctx.file_name
        load_job = client.load_table_from_uri(uri, table_ref, job_config=job_config)  # API request
        print("Starting job {}".format(load_job.job_id))
        load_job.result()  # Waits for table load to complete.
        print("Job finished.")
        destination_table = client.get_table(table_ref)
        print("Loaded {} rows.".format(destination_table.num_rows))
        


/

execute script ETL.bigquery_export('GOOGLE_CLOUD_STORAGE','test_1.csv','NICO2','NICO3','TEST','NUMBERS');

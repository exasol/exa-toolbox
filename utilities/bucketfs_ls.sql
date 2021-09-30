/*

    List the content of a BucketFS directory
    For more information on BucketFS see chapter 3.6.4 of the Exaso User Manual

    You might need to create a connection and grant it to your user first (e.g. if the bucket is not public):
        CREATE CONNECTION <my_bucket_access> TO 'bucketfs:<my_path>' IDENTIFIED BY '<read_password>';
        GRANT CONNECTION <my_bucket_access> TO <my_user>;

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_toolbox.bucketfs_ls(my_path VARCHAR(256)) EMITS (files VARCHAR(256)) AS
import os

def run(ctx):
	for line in os.listdir(ctx.my_path):
		ctx.emit(line)
/

-- Example:
-- SELECT bucketfs_ls('/buckets/bfsdefault/default');

-- EOF

/*

    List the content of a BucketFS directory
    For more information on BucketFS see https://docs.exasol.com/db/latest/database_concepts/bucketfs/bucketfs.htm

    You might need to create a connection and grant it to your user first (e.g. if the bucket is not public):
        CREATE CONNECTION <my_bucket_access> TO 'bucketfs:<my_path>' IDENTIFIED BY '<read_password>';
        GRANT CONNECTION <my_bucket_access> TO <my_user>;

*/

CREATE SCHEMA IF NOT EXISTS EXA_toolbox;

--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_toolbox.bucketfs_ls(my_path VARCHAR(256)) EMITS (size_bytes decimal, is_dir boolean, file_name VARCHAR(256)) AS

import os

def run(ctx):
	
	if os.path.isfile(ctx.my_path):
		ctx.emit(os.stat(ctx.my_path).st_size, False, os.path.basename(ctx.my_path))
		return

	for entry in os.scandir(ctx.my_path):
		ctx.emit(entry.stat().st_size if entry.is_file() else None, entry.is_dir(), entry.name)
/

-- Example:
-- SELECT bucketfs_ls('/buckets/bfsdefault/default');

--/
CREATE OR REPLACE PYTHON3 SCALAR SCRIPT EXA_toolbox.bucketfs_ls_old(my_path VARCHAR(256)) EMITS (files VARCHAR(256)) AS
import subprocess

def run(c):
    try:
        p = subprocess.Popen('ls -F ' + c.my_path,
                             stdout    = subprocess.PIPE,
                             stderr    = subprocess.STDOUT,
                             close_fds = True,
                             shell     = True,
                             encoding  = 'utf8'
                             )
        out, err = p.communicate()
        for line in out.strip().split('\n'):
            c.emit(line)
    finally:
        if p is not None:
            try: p.kill()
            except: pass
/

-- Example:
-- SELECT bucketfs_ls_old('/buckets/bfsdefault/default');

-- EOF

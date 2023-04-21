Objective
---------
This script will generate a backup of the metadata only (no data) of a database by creating a DDL's commands that then can be used to create all objects back on the same database or another.

Setup
-----

1. Download the files from github into a folder (Suggested location: “/usr/opt/metabackup"). See exact file list in the article.
2. Edit the file "config" and set the database name, path to EXAPLUS and a "External Location" if desire to store the backups there.
3. Create a profile in exaplus (exaplus -u xxx -p xxx -c xxx -wp profilename). The name should also be set on the "config" file. 
4. Please create the LUA scripts listed in "prereq_db_scripts" on the database or better execute backup.sh. This will create the database objects needed.

Note which schema they were created in (default is EXA_TOOLBOX).
   (if changed, please check other all files and make sure the schema name is correct specifically: "backup.sh", "createddl.sql")

Backup
------

1. Fill in all of the requirements that are in "backup.sh".
2. Run "backup.sh". This will create a schema called DB_HISTORY that will be removed after the backup is finished.
3. A tar.gz file will be moved to the secure location specified on the parameter EXTERNAL_DIR of the "config" file. Otherwise will be created on "./backups/".

Restore
-------

1. Untar the tar file containing the data to be restored.
2. Create an exaplus profile on the system using the user credentials (see above)
3. Fill in the requirements in "restore.sh".
4. Run "restore.sh".

Notes
----- 

1. If the metadata is from a different db version, the IMPORTs may fail. These can be adjusted manually afterwards.
2. During restore, profiling is enabled to look over anything that fails.
3. The backup will create a tar.gz file in “EXTERNAL_DIR”. This can be a shared filesystem mounted on startup via "/etc/rc.local_cos" file as:
   ...
   # Mount point for a share filesystem used by Metadata Backup
   mount -t nfs -o rw,nosuid,nodev,relatime,nfsvers=3,nolock,rsize=65536,wsize=65536,namlen=255,hard,proto=tcp,timeo=600,retrans=2,sec=sys,clientaddr=10.128.201.42,addr=10.128.102.83 my-nfs-01:/my_fs02_mppdb_0006 /mount/mppdb

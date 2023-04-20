#!/bin/env bash

SRC_PATH=$(dirname "$0")
source "$SRC_PATH"/config

DDL_DIR='ddls'
LOG_FILE_DIR='logs'
BACKUP_DIR='backups'
LOCK_FILE="$SYSPATH"/.lock
NOW=$(date +%Y-%m-%d-%H-%M-%S)

FUNC_NOW() {
    date +"[%Y-%m-%d %T.%6N]"
}

#Edit createddl.sql if you changed the name of the schema in prereq_db_scripts.sql
#Ensure DB LUA scripts BACKUP_SYS and BI_METADATA_BACKUPV2 have been created

#Create directories if they do not exist
mkdir -p "$SYSPATH" || { echo "$(FUNC_NOW) ERR: Could not create directory $SYSPATH"; exit 1; }
cd "$SYSPATH" || exit
mkdir -p "$LOG_FILE_DIR" "$DDL_DIR" "$BACKUP_DIR" || { echo "$(FUNC_NOW) ERR: Could not create directories"; exit 1; }
if [ -f "$DDL_DIR"/createddl.sql ]; then
    echo "$(FUNC_NOW) INFO: Createddl.sql exists"
else
    cp "$SYSPATH"/createddl.sql $DDL_DIR/
fi
if [ -f "$LOCK_FILE" ]; then
    echo "$(FUNC_NOW) ERR: Lock file exists, please check if process is already running otherwise remove lock file $LOCK_FILE and restart"
    exit 1;
else
    touch "$LOCK_FILE"
    #Check if EXAplus DB profile exists
    "$EXAPLUS"/exaplus -lp|grep -w "$PROFILENAME" -q
    PROFILE_EXISTS="$?"
    if [ $PROFILE_EXISTS -eq 0 ]; then
        echo "$(FUNC_NOW) INFO: EXAplus Profile found"
        echo "$(FUNC_NOW) INFO: DB connection profile exists, trying to connect to the database $DB_NAME"
        
        #Cleanup from previous run
        echo "$(FUNC_NOW) INFO: Cleaning up previous run"
        rm -f $DDL_DIR/ddl.sql
        "$EXAPLUS"/exaplus -q -profile "$PROFILENAME" -Q "$EXAPLUS_TIMEOUT" -L -retry "$EXAPLUS_RECONNECT" -f prereq_db_scripts.sql || { echo "$(FUNC_NOW) ERR: Could not run prereq script on DB ${DB_NAME}"; exit 1; }

        #Creates restore_sys.sql script
        echo "$(FUNC_NOW) INFO: Executing database backup script to create restore_sys.sql"
        "$EXAPLUS"/exaplus -q -profile "$PROFILENAME" -Q "$EXAPLUS_TIMEOUT" -L -retry "$EXAPLUS_RECONNECT" -sql "execute script backup_scripts.restore_sys;" > "${SYSPATH}/${DDL_DIR}/restore_sys.sql" || { echo "$(FUNC_NOW) ERR: Could not create restore_sys.sql script"; exit 1; }
        if [ -f "$DDL_DIR/restore_sys.sql" ]; then
            sed -i 's/^ *//; s/ *$//; /^$/d' "$DDL_DIR/restore_sys.sql"
        fi

        #Creates export_raw.sql 
        echo "$(FUNC_NOW) INFO: Executing database backup script to create export_raw.sql"
        "$EXAPLUS"/exaplus -q -profile "$PROFILENAME" -Q "$EXAPLUS_TIMEOUT" -L -retry "$EXAPLUS_RECONNECT" -sql "execute script backup_scripts.backup_sys('${SYSPATH}/${DDL_DIR}/');" > "${SYSPATH}/${DDL_DIR}/export_raw.sql" || { echo "$(FUNC_NOW) ERR: Could not create export_waw.sql script"; exit 1; }
        if [ -f "$DDL_DIR/export_raw.sql" ]; then
            sed -i '1,3d' "$DDL_DIR/export_raw.sql"
            if [ -f $DDL_DIR/export_raw.sql ] && [ -f $DDL_DIR/createddl.sql ]; then
                echo "$(FUNC_NOW) INFO: Running export.sql and createddl.sql this might take some time"
                "$EXAPLUS"/exaplus -q -profile "$PROFILENAME" -Q "$EXAPLUS_TIMEOUT" -L -retry "$EXAPLUS_RECONNECT" -f "$SYSPATH/$DDL_DIR/export_raw.sql" > "$SYSPATH/$LOG_FILE_DIR/export_sql_logs-${NOW}.txt" || { echo "$(FUNC_NOW) ERR: Could not connect to DB ${DB_NAME}"; exit 1; }
                "$EXAPLUS"/exaplus -q -profile "$PROFILENAME" -Q "$EXAPLUS_TIMEOUT" -L -retry "$EXAPLUS_RECONNECT" -f "$SYSPATH/$DDL_DIR/createddl.sql" > "$SYSPATH/$LOG_FILE_DIR/createddl_log-${NOW}.txt" || { echo "$(FUNC_NOW) ERR: Could not connect to DB ${DB_NAME}"; exit 1; }
                if [ -f "ddl.sql" ]; then
                    mv ddl.sql $DDL_DIR/ddl.sql
                    echo "$(FUNC_NOW) INFO: Cleaning up sqls"
                    rm -f $DDL_DIR/export_raw.sql
                    rm -f $DDL_DIR/export.sql
                    echo "$(FUNC_NOW) INFO: Creating archive with DDLs"
                    TARTIMESTAMP=$NOW
                    tar zcf "$BACKUP_DIR"/ddl-backup-"${DB_NAME}"-"${TARTIMESTAMP}".tar.gz "$DDL_DIR"/* || { echo "$(FUNC_NOW) ERR: Could not create TAR of DDLs"; exit 1; }
                    if [ -f "$BACKUP_DIR"/ddl-backup-"${DB_NAME}"-"${TARTIMESTAMP}".tar.gz ]; then
                        # Copy TAR.GZ file to an external location
                        if [ "$(findmnt -m "$EXTERNAL_DIR")" ]; then
                            cp "$BACKUP_DIR"/ddl-backup-"${DB_NAME}"-"${TARTIMESTAMP}".tar.gz "$EXTERNAL_DIR"/ddl-backup-"${DB_NAME}"-"${TARTIMESTAMP}".tar.gz
                            if [ -f "$EXTERNAL_DIR"/ddl-backup-"${DB_NAME}"-"${TARTIMESTAMP}".tar.gz ]; then
                                echo "$(FUNC_NOW) INFO: Removing TAR file from '$SYSPATH/$BACKUP_DIR' after copying to '$EXTERNAL_DIR'"
                                rm -f "$BACKUP_DIR"/ddl-backup-"${DB_NAME}"-"${TARTIMESTAMP}".tar.gz
                            fi
                        else
                            echo "$(FUNC_NOW) WARN: Copying TAR file to '$EXTERNAL_DIR' failed"
                        fi
                        echo "$(FUNC_NOW) INFO: Removing lock file"
                        rm "$LOCK_FILE"
                        echo "$(FUNC_NOW) INFO: Metadata backup of $DB_NAME done"
                        exit 0
                    else
                        echo "$(FUNC_NOW) ERR: Creating TAR failed"
                        exit 1
                    fi
                else
                    echo "$(FUNC_NOW) ERR: Could not find file ddl.sql"
                    echo "----------------->>>>"
                    exit 1
                fi
            else
                echo "$(FUNC_NOW) ERR: File $SYSPATH/$DDL_DIR/export.sql or $SYSPATH/$DDL_DIR/createddl.sql does not exist"
                echo "----------------------------------------------------------------------------------->>>>"
                exit 1
            fi
        else
            echo "$(FUNC_NOW) ERR: Could not find file $SYSPATH/$DDL_DIR/export_raw.sql"
            echo "---------------------------------------------------->>>>"
            exit 1
        fi
    else
        echo "$(FUNC_NOW) ERR: Please create a DB connection profile with exaplus"
        echo "exaplus -wp metadata_backup_profile -u sys -p exasol -c 10.70.10.140:8563"
        echo "------------------------------------------------------------------------->>>>"
        exit 1
    fi
fi

#!/bin/env bash

SRC_PATH=$(dirname "$0")
source "$SRC_PATH"/config

LOCK_FILE=${RESTORE_SYS_SQL_PATH}/.lock

FUNC_NOW() {
    date +"[%Y-%m-%d %T.%6N]"
}

if [ -f "$LOCK_FILE" ];then
    echo "$(FUNC_NOW) ERR: Lock file exists, please check and remove. Maybe previous run was interrupted?"
    exit 1
else
    if [ -d "$BACKUP_RESTORE_PATH" ]; then
        echo "$(FUNC_NOW) INFO: Backup restore path $BACKUP_RESTORE_PATH found"
        #Check if explus profile exists
        "$EXAPLUS"/exaplus -lp|grep -w "$PROFILENAME" -q
        PROFILE_EXISTS="$?"
        if [ "$PROFILE_EXISTS" -eq 0 ]; then
            echo "$(FUNC_NOW) INFO: EXAplus profile found" 
            echo "$(FUNC_NOW) INFO: Starting restore of SYS schema"
            touch "$LOCK_FILE"
            "$EXAPLUS"/exaplus -profile "$PROFILENAME" -f "$RESTORE_SYS_SQL_PATH"/restore_sys.sql -- "$BACKUP_RESTORE_PATH" || { echo "$(FUNC_NOW) ERR: Could not connect to DB ${DB_NAME}"; exit 1; }
            echo "$(FUNC_NOW) INFO: Starting restore of DDLs"
            "$EXAPLUS"/exaplus -profile "$PROFILENAME" -f "$BACKUP_RESTORE_PATH"/ddl.sql || { echo "$(FUNC_NOW) ERR: Could not connect to DB ${DB_NAME}"; exit 1; }
            rm "$LOCK_FILE"
            echo "$(FUNC_NOW) INFO: Restore done"
            exit 0
        else
            echo "$(FUNC_NOW) ERR: Please create a DB connection profile with exaplus"
            echo "exaplus -wp metadata_backup_profile -u sys -p exasol -c 10.70.10.140:8563"
            exit 1
        fi
    else
        echo "$(FUNC_NOW) ERR: Backup restore directory not found $BACKUP_RESTORE_PATH"
        echo "$(FUNC_NOW) ERR: Please unpack TAR"
        exit 1
    fi
fi

#/bin/bash
#
# MySQL/MariaDB backup script
#
# Use cron to schedule this script to run as frequently as you want.
# Uses iam role for S3 permission
###################################################################################

echo "start_time: " `date`

# User with SELECT, SHOW VIEW, EVENT, and TRIGGER, or... root
USERNAME='root'
PASSWORD='{{ voip_maria_db_root_password }}'


S3_BUCKET={{ s3_bucket_name }}
S3_TIME=21
NOW_TIME=$(date +%H)


# Archive path
ARCHIVE_PATH="/var/backups"
/bin/mkdir -p $ARCHIVE_PATH


# Archive filename
ARCHIVE_FILE="databases_`date +%F_%H-%M-%S`.tbz2"

# Local archives older than this will be deleted
ARCHIVE_DAYS="15"


# Get all of the databases
for database in `/usr/bin/mysql -u $USERNAME -p"$PASSWORD" -Bse 'show databases'`; do
        # Skip ones we don't want to back up
        if [ "performance_schema" == "$database" ]; then continue; fi
        if [ "information_schema" == "$database" ]; then continue; fi
        echo "Dumping: $database"
        # Use Nice to dump the database
        nice mysqldump --routines -u $USERNAME -p"$PASSWORD" --verbose --events $database > $ARCHIVE_PATH/$database.sql

done


# Use Nice to create a tar compressed with bzip2
nice tar -cvjf $ARCHIVE_PATH/$ARCHIVE_FILE $ARCHIVE_PATH/*.sql


# Remove the SQL files
nice rm -rvf $ARCHIVE_PATH/*.sql


# Remove old archive files
nice find $ARCHIVE_PATH -mtime +$ARCHIVE_DAYS -exec rm -v {} \;


if [ $S3_TIME -eq $NOW_TIME ]
then
    aws s3 cp ${ARCHIVE_PATH}/$ARCHIVE_FILE s3://${S3_BUCKET}/backup/voip/${ARCHIVE_FILE}
fi

echo "end_time: " `date`

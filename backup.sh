#!/bin/bash
#
# To Do - Add logging of output.
# To Do - Abstract bucket region to options

set -e

export PATH="$PATH:/usr/local/bin"

usage()
{
cat << EOF
usage: $0 options

This script dumps the current mongo database, tars it, then sends it to an Amazon S3 bucket.

OPTIONS:
   -help   Show this message
   -h      Mongodb host <hostname><:port>
   -d      Backup directory
   -b      Amazon S3 bucket name
EOF
}

MONGODB_HOST=
S3_BUCKET=
DIR=

while getopts "h:u:p:o:k:s:r:d:b:" OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    o)
      MONGODB_HOST=$OPTARG
      ;;
    d)
      DIR=$OPTARG
      ;;
    b)
      S3_BUCKET=$OPTARG
      ;;
    ?)
      usage
      exit
    ;;
  esac
done

if [[ -z $S3_BUCKET ]]
then
  usage
  exit 1
fi
if [[ -z $MONGODB_HOST ]]
then
  MONGODB_HOST="localhost:27017"
fi

# Get the directory the script is being run from
#DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo Backing up to $DIR
# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date -u "+%F-%H%M%S")
FILE_NAME="backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Lock the database
# Note there is a bug in mongo 2.2.0 where you must touch all the databases before you run mongodump
echo Locking database...
mongo -host "$MONGODB_HOST" admin --eval "rs.slaveOk(); var databaseNames = db.getMongo().getDBNames(); for (var i in databaseNames) { printjson(db.getSiblingDB(databaseNames[i]).getCollectionNames()) }; printjson(db.fsyncLock());"

# Dump the database
echo Dumping database...
mongodump -host "$MONGODB_HOST" --out $DIR/backups/$FILE_NAME

# Unlock the database
echo Unlocking database...
mongo -host "$MONGODB_HOST" admin --eval "rs.slaveOk(); printjson(db.fsyncUnlock());"

# Tar Gzip the file
echo Zipping database dump $FILE_NAME to $ARCHIVE_NAME
tar -C $DIR/backups/ -zcvf $DIR/backups/$ARCHIVE_NAME $FILE_NAME/

# Remove the backup directory
echo Removing backupd directory $FILE_NAME
rm -r $DIR/backups/$FILE_NAME

# Send the file to S3
echo Sending zip to S3 $S3_BUCKET $ARCHIVE_NAME
DATE_YYYY=$(date -u "+%Y")
DATE_YYYYMM=$(date -u "+%Y-%m")
s3cmd put $DIR/backup/$ARCHIVE_NAME s3://$S3_BUCKET/$ARCHIVE_NAME

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
   -u      Mongodb user
   -p      Mongodb password
   -h      Mongodb host <hostname><:port>
   -b      Amazon S3 bucket name
EOF
}

MONGODB_USER=
MONGODB_PASSWORD=
MONGODB_HOST=
S3_BUCKET=

while getopts “h:u:p:o:k:s:r:b:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    u)
      MONGODB_USER=$OPTARG
      ;;
    p)
      MONGODB_PASSWORD=$OPTARG
      ;;
    o)
      MONGODB_HOST=$OPTARG
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

if [[ -z $MONGODB_USER ]] || [[ -z $MONGODB_PASSWORD ]] || [[ -z $S3_BUCKET ]]
then
  usage
  exit 1
fi
if [[ -z $MONGODB_HOST ]]
then
  MONGODB_HOST="localhost:27017"
fi

# Get the directory the script is being run from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
# Store the current date in YYYY-mm-DD-HHMMSS
DATE=$(date -u "+%F-%H%M%S")
FILE_NAME="backup-$DATE"
ARCHIVE_NAME="$FILE_NAME.tar.gz"

# Lock the database
# Note there is a bug in mongo 2.2.0 where you must touch all the databases before you run mongodump
mongo -username "$MONGODB_USER" -password "$MONGODB_PASSWORD" -host "$MONGODB_HOST" admin --eval "rs.slaveOk(); var databaseNames = db.getMongo().getDBNames(); for (var i in databaseNames) { printjson(db.getSiblingDB(databaseNames[i]).getCollectionNames()) }; printjson(db.fsyncLock());"

# Dump the database
mongodump -username "$MONGODB_USER" -password "$MONGODB_PASSWORD" -host "$MONGODB_HOST" --out $DIR/backup/$FILE_NAME

# Unlock the database
mongo -username "$MONGODB_USER" -password "$MONGODB_PASSWORD" -host "$MONGODB_HOST" admin --eval "rs.slaveOk(); printjson(db.fsyncUnlock());"

# Tar Gzip the file
tar -C $DIR/backup/ -zcvf $DIR/backup/$ARCHIVE_NAME $FILE_NAME/

# Remove the backup directory
rm -r $DIR/backup/$FILE_NAME

# Send the file to S3
DATE_YYYY=$(date -u "+%Y")
DATE_YYYYMM=$(date -u "+%Y-%m")
s3cmd put $DIR/backup/$ARCHIVE_NAME s3://$S3_BUCKET/$DATE_YYYY/$DATE_YYYYMM/$ARCHIVE_NAME
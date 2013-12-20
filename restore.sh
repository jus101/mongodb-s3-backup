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

This script retrieves the latest mongo dumpfile from Amazon S3,
and restores it to specified database.

OPTIONS:
   -help   Show this message
   # -u      OPTIONAL: Mongodb user
   # -p      OPTIONAL: Mongodb password
   -o      OPTIONAL: Default is "localhost:27017"
           Mongodb host <hostname><:port>
   -f      Mongodb database(from)
   -t      OPTIONAL: Default is same as -t options value
           Mongodb database(to)
   -b      Amazon S3 bucket name
EOF
}

# MONGODB_USER=
# MONGODB_PASSWORD=
MONGODB_HOST=
MONGODB_DATABASE_FROM=
MONGODB_DATABASE_TO=
S3_BUCKET=

while getopts “h:u:p:o:f:t:b:” OPTION
do
  case $OPTION in
    h)
      usage
      exit 1
      ;;
    # u)
    #   MONGODB_USER=$OPTARG
    #   ;;
    # p)
    #   MONGODB_PASSWORD=$OPTARG
    #   ;;
    o)
      MONGODB_HOST=$OPTARG
      ;;
    f)
      MONGODB_DATABASE_FROM=$OPTARG
      ;;
    t)
      MONGODB_DATABASE_TO=$OPTARG
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

if [[ -z $S3_BUCKET ]] || [[ -z $MONGODB_DATABASE_FROM ]]
then
  usage
  exit 1
fi
if [[ -z $MONGODB_HOST ]]
then
  MONGODB_HOST="localhost:27017"
fi
if [[ -z $MONGODB_DATABASE_TO ]]
then
  MONGODB_DATABASE_TO=$MONGODB_DATABASE_FROM
fi


# Get the directory the script is being run from
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo $DIR
OUT_DIR=$DIR/restore

DATE_YYYY=$(date -u "+%Y")
DATE_YYYYMM=$(date -u "+%Y-%m")
LATEST_FILE_PATH=$(s3cmd ls s3://$S3_BUCKET/$DATE_YYYY/$DATE_YYYYMM/ | sort -r | head -1 | awk '{print $4}')
echo $LATEST_FILE_PATH
s3cmd get $LATEST_FILE_PATH $OUT_DIR/

TAR_FILE_NAME="$( ls -rt $OUT_DIR | tail -1 )"

# Untar Gzip the file
tar zxvf $OUT_DIR/$TAR_FILE_NAME -C $OUT_DIR

# Remove the tar file
rm $OUT_DIR/$TAR_FILE_NAME

# restore
DUMP_DIR="$( ls -rt $OUT_DIR | tail -1 )"
echo $OUT_DIR/$DUMP_DIR/$MONGODB_DATABASE_FROM
mongorestore --host $MONGODB_HOST --db $MONGODB_DATABASE_TO --drop $OUT_DIR/$DUMP_DIR/$MONGODB_DATABASE_FROM


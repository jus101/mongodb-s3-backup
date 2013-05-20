# Mongodb to Amazon s3 Backup Script

## Requirements

* Running mongod process
* mongodump
* mongo
* (configured)s3cmd
* tar
* rm
* curl

## Usage

`bash /path/to/backup.sh -u MONGODB_USER -p MONGODB_PASSWORD -b S3_BUCKET`

## Cron

### Daily

Add the following line to `/etc/cron.d/db-backup` to run the script every day at midnight (UTC time)

    0 0 * * * root /bin/bash /path/to/backup.sh -u MONGODB_USER -p MONGODB_PASSWORD -b S3_BUCKET`


#!/bin/bash
# Script för att backa upp mysql-databasen...
# Axel Larsson 2012-01-07
datum=`date +%Y-%m-%d_%H.%M`
backupDir="/media/data/public/Backup/Ubuntuservern/mysqldatabases"
mkdir -p $backupDir
user="EDIT"
password="EDIT"
# Backar upp alla databaser
mysqldump -u $user -p$password --all-databases > $backupDir/$datum.sql

exit 0


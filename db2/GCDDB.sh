#! /bin/bash
#
# Licensed Materials - Property of IBM
# 5747-SM3
# (c) Copyright IBM Corp. 2017,2018  All Rights Reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure restricted by GSA ADP Schedule Contract with IBM Corp.
#
if [ $# -eq 0 ]
then
  echo
 echo  Usage: $0 "<database_name>"
  echo
  exit 1
fi

arg1=$1
#len=`echo "${arg1}\c" |wc -c`
len=${#arg1}
if [ $len -gt 8 ]
then
  echo
  echo Invalid DB name "$arg1" : Must be 8 characters or less.
  echo DB creation would fail.  Exiting...
  echo
  exit 1
fi

P8DBNAME=$1
P8DBDIR=/home/db2inst1/db2fs/${P8DBNAME}
DB2USER=db2inst1

mkdir -p ${P8DBDIR}

#-- Close any outstanding connection
db2 CONNECT RESET

db2 +p -t <<End_of_file
CREATE DATABASE $P8DBNAME
AUTOMATIC STORAGE YES
ON $P8DBDIR
USING CODESET UTF-8 TERRITORY US
COLLATE USING SYSTEM
PAGESIZE 32768
;

-- Increase the application heap size
UPDATE DATABASE CONFIGURATION FOR ${P8DBNAME} USING APPLHEAPSZ 2560;
UPDATE DATABASE CONFIGURATION FOR ${P8DBNAME} USING STMTHEAP 8192;

End_of_file

sleep 5

db2 +p -t <<End_of_file
-- Connect
CONNECT TO $P8DBNAME;
-- Drop unnecessary default tablespaces
-- Try not dropping
DROP TABLESPACE USERSPACE1;
-- REVOKE USE OF TABLESPACE USERSPACE1 FROM PUBLIC;
-- Create default buffer pool size
CREATE Bufferpool FNCEDEFAULTBP IMMEDIATE  SIZE -1 PAGESIZE 32 K;

End_of_file

db2 CONNECT RESET
db2 deactivate database $P8DBNAME
sleep 5

db2 CONNECT TO $P8DBNAME

db2 +p -t <<End_of_file
-- Create tablespaces
CREATE REGULAR
   TABLESPACE ${P8DBNAME}_TBS
   PAGESIZE 32 K
   MANAGED BY AUTOMATIC
   STORAGE EXTENTSIZE 16 OVERHEAD 10.5
   PREFETCHSIZE 16 TRANSFERRATE 0.14
   BUFFERPOOL "FNCEDEFAULTBP"
   DROPPED TABLE RECOVERY ON
;

CREATE SYSTEM TEMPORARY
   TABLESPACE TEMPSYS1
   PAGESIZE 32 K
   MANAGED BY AUTOMATIC
   STORAGE EXTENTSIZE 16 OVERHEAD 10.5
   PREFETCHSIZE 16 TRANSFERRATE 0.14
   BUFFERPOOL "FNCEDEFAULTBP"
;

End_of_file

#-- Grant USER access to tablespaces
echo Grant user $DB2USER access to tablespace

#db2 -v GRANT CREATETAB,CONNECT ON DATABASE  TO user $DB2USER;
#db2 -v GRANT USE OF TABLESPACE ${P8DBNAME}_TBS TO user $DB2USER;
#db2 -v GRANT USE OF TABLESPACE USERTEMP1 TO user $DB2USER;
#db2 -v GRANT SECADM, DBADM ON DATABASE TO user $DB2USER;

# apply DB tuning
db2 update db cfg for ${P8DBNAME} using LOCKTIMEOUT 30
db2 update db cfg for ${P8DBNAME} using LOGBUFSZ 212
db2 update db cfg for ${P8DBNAME} using LOGFILSIZ 6000
db2 update db cfg for ${P8DBNAME} using APPLHEAPSZ 2560
db2 update db cfg for ${P8DBNAME} using LOGPRIMARY 10

export CUR_COMMIT=ON
db2 update db cfg using cur_commit ON

#-- Close connection
db2 CONNECT RESET

db2 activate database $P8DBNAME

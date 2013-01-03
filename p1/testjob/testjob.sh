#!/bin/sh

#$ -o /home/churas/panfish/p1/testjob/stdout
#$ -e /home/churas/panfish/p1/testjob/stderr

HI=`date +%s`
XFILE=`uuidgen`
echo "hi time is: $HI" > "${XFILE}.txt"
sleep 30
exit


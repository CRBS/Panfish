#!/bin/bash

if [ $# -ne 1 ] ; then
   echo "$0 <test data directory>"
   echo "This script benchmarks panfishchum vs rsync"
   echo ""
   echo "The test is run as follows:"
   echo ""
   echo "1) <test data directory> on remote cluster (gordon) is deleted via panfishland"
   echo "2) [command] is run to upload <test data directory> and time is recorded"
   echo ""
   echo "Steps 1,2 are repeated 18 times each for panfishchum and rsync in an alternating fashion"
   echo "With the first two times excluded from statistics"
   echo "Output:"
   echo "Program,Min Time, Max Time,Median Time, Average Time"
   echo "panfishchum,0,10,5,5"
   echo "rsync,0,10,4,4"
   exit 1
fi

TESTDIR=$1

REMOTEHOST="churas@gordon.sdsc.edu"
BASEDIR="/projects/ps-camera/gordon/panfish/coleslaw"

if [ ! -d $TESTDIR ] ; then
  echo "$TESTDIR is not a directory"
  exit 1
fi

#
#
#
function delete_path {
   panfishland --cluster gordon_shadow.q --deleteonly --path $TESTDIR 2>&1 > /dev/null

  if [ $? != 0 ] ; then
    panfishland --cluster gordon_shadow.q --deleteonly --path $TESTDIR 2>&1 > /dev/null
  fi
}


echo "rsync,panfishchum"

for Y in `seq 1 16` ; do

  sleep 60
  delete_path
  sleep 60

  #
  # rsync
  #
  RSYNCOUTPUT=`/usr/bin/time -p /usr/bin/rsync -rtpz  --stats --timeout=180 -e "/usr/bin/ssh" $TESTDIR churas@gordon.sdsc.edu:${BASEDIR}/${TESTDIR} 2>&1 | egrep "^real" | sed "s/^real //"`
 
  if [ $? != 0 ] ; then
     RSYNCOUTPUT="-1"
  fi
  sleep 60
  delete_path
  sleep 60
  #
  # panfishchum
  #
  PANFISHCHUMOUTPUT=`/usr/bin/time -p panfishchum --cluster gordon_shadow.q --path $TESTDIR 2>&1 | egrep "^real" | sed "s/^real //"`
 
  if [ $? != 0 ] ; then
    PANFISHCHUMOUTPUT="-1"
  fi 

  echo "$RSYNCOUTPUT,$PANFISHCHUMOUTPUT"
done


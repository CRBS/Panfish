#!/bin/bash

if [ $# -ne 1 ] ; then
   echo "$0 <test data directory>"
   echo "This script benchmarks panfishland vs rsync"
   echo ""
   echo "The test is run as follows:"
   echo ""
   echo "1) <test data directory> on local cluster is deleted"
   echo "2) [command] is run to download <test data directory> and time is recorded"
   echo ""
   echo "Steps 1,2 are repeated 18 times each for panfishland and rsync in an alternating fashion"
   echo "With the first two times excluded from statistics"
   echo "Output:"
   echo "rsyncdownload,panfishland"
   echo "1,1"
   echo "2,2"
   exit 1
fi

TESTDIR=$1

REMOTEHOST="churas@gordon.sdsc.edu"
BASEDIR="/projects/ps-camera/gordon/panfish/coleslaw"

echo "WARNING: $TESTDIR WILL BE DELETED.  You have 10 seconds to hit Ctrl-C if you dont want this"
sleep 10

#
#
#
function delete_path {
  # echo "Deleting $TESTDIR"
   /bin/rm -rf $TESTDIR   
  # if [ ! -e $TESTDIR ] ; then
  #     echo "$TESTDIR gone"
  # else
  #     echo "WHAT THE $TESTDIR is still here"
  # fi
}


echo "rsyncdown,panfishland"

for Y in `seq 1 16` ; do

  sleep 10
  delete_path
  sleep 10

  #
  # rsync
  #
  RSYNCOUTPUT=`/usr/bin/time -p /usr/bin/rsync -rtpz  --stats --timeout=180 -e "/usr/bin/ssh" churas@gordon.sdsc.edu:${BASEDIR}/${TESTDIR} $TESTDIR 2>&1 | egrep "^real" | sed "s/^real //"`
 
  if [ $? != 0 ] ; then
     RSYNCOUTPUT="-1"
  fi
  sleep 10
  delete_path
  sleep 10
  #
  # panfishland
  #
  PANFISHCHUMOUTPUT=`/usr/bin/time -p panfishland --cluster gordon_shadow.q --path $TESTDIR 2>&1 | egrep "^real" | sed "s/^real //"`
 
  if [ $? != 0 ] ; then
    PANFISHCHUMOUTPUT="-1"
  fi 

  echo "$RSYNCOUTPUT,$PANFISHCHUMOUTPUT"
done


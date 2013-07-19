#!/bin/bash

if [ $# -ne 3 ] ; then
   echo "$0 <test job directory> <cluster> <# jobs>"
   echo "This script benchmarks panfishcast vs qsub"
   echo ""
   echo "The test is run as follows:"
   echo ""
   echo "1) <test job directory> is deleted and recreated"
   echo "2) test.sh is created which runs sleep for 10 seconds"
   echo "3) Job submitted via qsub or panfishcast"
   echo ""
   echo "Steps 1-3 are repeated 18 times each for panfishcast & qsub in an alternating fashion"
   echo "Output:"
   echo "qsub,panfishcast"
   echo "1,1"
   echo "2,2"
   exit 1
fi

TESTDIR=$1
CLUSTER=$2
NUMJOBS=$3

if [ ! -d $TESTDIR ] ; then
  echo "$TESTDIR is not a directory"
  exit 1
fi

echo "WARNING: $TESTDIR WILL BE DELETED.  You have 10 seconds to hit Ctrl-C if you dont want this"
sleep 10

CURDIR=`pwd`

#
#
#
function delete_path {
   /bin/rm -rf $TESTDIR   
}


# 
#
#
function create_testjob {

  mkdir -p $TESTDIR
  echo "#!/bin/bash" > $TESTDIR/testjob.sh
  echo "echo \"Hello World\"" >> $TESTDIR/testjob.sh
  echo "exit 0" >> $TESTDIR/testjob.sh
  chmod a+x $TESTDIR/testjob.sh
}


echo "panfishcastremote"

for Y in `seq 1 16` ; do

  sleep 10
  delete_path
  create_testjob

  #
  # panfishchum to upload
  #
  panfishchum --cluster $CLUSTER --path $TESTDIR


  cd $TESTDIR  
  #
  # panfishcast
  #
  PANFISHCASTOUTPUT=`/usr/bin/time -p panfishcast -q $CLUSTER -sync y -t 1-${NUMJOBS} -e $TESTDIR/t.e -o $TESTDIR/t.o $TESTDIR/testjob.sh 2>&1 | egrep "^real" | sed "s/^real //"`
 
  if [ $? != 0 ] ; then
    PANFISHCASTOUTPUT="-1"
  fi 

  #panfishland --deleteonly --cluster $CLUSTER --path $TESTDIR 
  echo "Remove the exit thingy"
  exit 1
  cd $CURDIR
  echo "$PANFISHCASTOUTPUT"
done


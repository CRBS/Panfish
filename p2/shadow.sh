#!/bin/bash


on_usr2() {
  echo "Caught USR2 signal...informing children...exiting..."
  echo "Killed by signal" > $JOB_FILE.killed
  exit 100
}

trap 'on_usr2' USR2

function wait_for_job {
   #this should be in a config file and may need to be increased
   DONE_JOB_FILE="$JOB_FILE.done"
   FAILED_JOB_FILE="$JOB_FILE.failed"
   while [[ ! -e $DONE_JOB_FILE && ! -e $FAILED_JOB_FILE ]] ; do
     echo "Job not completed... waiting... 60 seconds"
     sleep 60
   done
   if [ -e $DONE_JOB_FILE ] ; then
     return 0
   fi

   if [ -e $FAILED_JOB_FILE ] ; then
     return 1
   fi
}

echo "This is my host: $HOSTNAME"
echo "This is my queue: $QUEUE"
echo "This is my current working directory: `pwd`"
echo "This is my TMPDIR: $TMPDIR"
echo "JOb id: $JOB_ID"
echo "task id: $SGE_TASK_ID"
PROPFILE="`dirname $0`/panfish.properties"

SUBMIT_DIR=`egrep "^submit.dir" $PROPFILE | sed "s/^.*= *//"`




#what do I need to do?  Well lets assume you have everything 
#already staged file wise.  so all we need to do is submit
# the job passed in as arguments adjusting the script path to
# the remote host and wait for it to finish. 

JOB_FILE="$SUBMIT_DIR/$QUEUE/$JOB_ID.$SGE_TASK_ID.job"

echo "`pwd`ENDCURRENTDIR$*" > $JOB_FILE

if [ $? != 0 ] ; then
  echo "Error running job"
  exit 1
fi

wait_for_job $JOBID
JOB_EXIT=$?

echo "Job Completed `date +%s` with exit: $JOB_EXIT"

exit $JOB_EXIT

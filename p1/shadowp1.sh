#!/bin/bash


#this script takes another script along
#with its arguments and depending on
# what queue it ends up on it submits
# and then waits for that job to complete
# performing the copy up and copy back
# procedure as well as appropriately 
# setting all necessary environment
# variables 
# it is assumed all scripts, files, and
# directories are in place.  The program
# merely handles the differences from each
# cluster and submits the job





function submit_job {
  
    
    THECMD=`echo "$REMOTEDIR/$2"`
   
    echo "Running: ssh $REMOTEHOST $MYQSUB $THECMD"  

    JOBID=`ssh $REMOTEHOST "cd $REMOTEDIR/$1;$MYQSUB $THECMD" 2>&1`
   
    if [ $? != 0 ] ; then
       echo "Error ssh : $REMOTEHOST $MYQSUB $THECMD : $JOBID"
       return 1
    fi
    echo "$JOBID"
    return 0
}

function wait_for_job {
   #this should be in a config file and may need to be increased
   
   while [ "$JOBSTATUS" != "COMPLETED" ] ; do
      echo "Sleeping 60 seconds"
      sleep 60
      echo "Check job status start time: `date +%s`"
      #check status of job on remoteblast
      FUN=`echo "$GETJOBSTATUS $1"`
      echo "Running: ssh $REMOTEHOST $FUN"
      JOBSTATUS=`ssh $REMOTEHOST $FUN`

      if [ $? != 0 ] ; then
         echo "Error : $? : $JOBSTATUS"
         echo "There was a problem determining job status.  Will err on side of "
         echo "caution and assume its just a ssh hiccup and will try again later"
      fi
      echo "Check job status end time: `date +%s`"
      echo "Got: $JOBSTATUS"
   done
}

echo "This is my host: $HOSTNAME"
echo "This is my queue: $QUEUE"
echo "This is my current working directory: `pwd`"
echo "This is my TMPDIR: $TMPDIR"

PROPFILE="`dirname $0`/shadow.properties"

REMOTEHOST=`egrep "^$QUEUE.host" $PROPFILE | sed "s/^.*= *//"`

echo "This is my remote host: $REMOTEHOST"

REMOTEDIR=`egrep "^$QUEUE.basedir" $PROPFILE | sed "s/^.*= *//"`

echo "This is my remote dir: $REMOTEDIR"

MYQSUB=`egrep "^$QUEUE.myqsub" $PROPFILE | sed "s/^.*= *//"`

GETJOBSTATUS=`egrep "^$QUEUE.getjobstatus" $PROPFILE | sed "s/^.*= *//"`

#what do I need to do?  Well lets assume you have everything 
#already staged file wise.  so all we need to do is submit
# the job passed in as arguments adjusting the script path to
# the remote host and wait for it to finish. 

submit_job `pwd` $1

if [ $? != 0 ] ; then
  echo "Error running job"
  exit 1
fi

wait_for_job $JOBID


echo "Job Completed `date +%s`"

exit 0

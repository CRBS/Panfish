
Panfish Technical Specification
================================

By Christopher Churas


Overview
========

Panfish is a set of applications that enable Grid Engine serial jobs to be run on
remote clusters.  

This specification will discuss the Panfish technical implementation.

THIS SPECIFICATION MAY CONTAIN ERRORS AND OMISSIONS.  YOU HAVE BEEN WARNED.


Requirements
============

* Must support Sun Grid Engine/Grid Engine or OpenPBS/Torque on remote clusters.

* Only access to the remote clusters will be through ssh.  This requirement is here
  because most XSEDE resources only offer an ssh account and some storage on the 
  remote host.  They then instruct the user to follow this flow:
  
    Upload data ---> Run job ---> Download data ---> repeat if needed.

* Local cluster must be Sun Grid Engine/Grid Engine.


How Panfish Works
=================

Panfish takes a script based commandline job and handles invocation as well
as assists in the serialization and deserialization of data to remote clusters.

Panfish is not a batch processing scheduler on its own, it can be thought of as
a wrapper on top of Sun Grid Engine that handles the logistics of ferrying jobs
to/from remote clusters.  

The benefit of a wrapper is most jobs that work in Sun Grid Engine could in 
theory be run through Panfish with only minimal changes.

In a normal scenario the user does the following:

    User ----> [invokes] ----> qsub
     ||                         ||
     ||                         \/
     ||  <---------- [returns job id to caller]
     \/
    User ----> [invokes] ----> qstat
     ||                         ||
     ||                         \/
     ||  <------------- [returns job status]
     \/
    Done

With **Panfish** the user does the following:

    User ----> [invokes] ----> cast
     ||                         ||
     ||                         \/
     ||  <--------- [returns job id to caller]
     \/
    User ----> [invokes] ----> qstat
     ||                         ||
     ||                         \/
     ||  <------------- [returns job status]
     \/
    User ----> [invokes] ----> land
     ||                         ||
     ||                         \/
    Done <-------- [data retreived from clusters]


The way it works is invocation of **cast** by a user submits a shadow job 
to the local queuing system.  As part of the submission a list of valid
shadow queues is set which correspond to remote clusters the job can run
under.  The user is given the id of the shadow job by the **cast** command.  
The user then simply waits for those jobs to complete through calls to **qstat**

Sun Grid Engine then schedules the shadow job to the appropriate cluster.  
Once the shadow job starts it informs **Panfish** that a job can be run on a 
cluster as defined by the queue the shadow job was run under.  **Panfish** 
then runs the job on the remote cluster and informs the shadow job when the 
real job completes.  

Upon detecting all jobs have completed, the user invokes **land** to retreive
data from all the clusters.

Now a detail was left out in the above paragraphs that is pretty important.  
Before any job can run on the remote clusters, the job and its corresponding 
data need to reside there.  Something needs to upload the data and that 
responsibility can be left to the user or to **cast** by setting a directive on 
the command line saying "hey upload this directory" or through a directive within 
the script.  

Another issue that needs to be dealt with involves paths.  **Panfish** requires all file
paths to be prefixed with the environment variable **PANFISH_BASEDIR** which will be set
appropriately on each cluster, (or not set at all if the job ends up locally.)  For example
say we had this job script:

    #!/bin/bash

    echo "Today is: `date`" > /home/foo/j1/thedate.txt

If the above was run on the remote cluster it may fail cause **/home/foo/j1** may not
exist on that cluster.  To deal with this the job needs to prefix all paths with 
**PANFISH_BASEDIR**  as seen here:

    #!/bin/bash

    echo "Today is: `date`" > $PANFISH_BASEDIR/home/foo/j1/thedate.txt

Now **Panfish** can run the job under an alternate path but still keep the rest of the
path intact.  

Here is a more in depth diagram denoting the flow of a job through **Panfish**


Diagram of flow
---------------

    User ---> [invokes] ----> Cast
     ||                        ||
     ||                        \/
     ||          [Pushes data to remote clusters]
     ||                        ||
     ||                        \/
     ||          [Invokes qsub on line command]  
     ||                        ||
     ||                        \/
     ||  <------ [returns submitted line job id] ---->  line
     \/                                                  ||
    User ---> [invokes] ---> qstat                       \/
     ||                       ||            [Generates job file based on queue] --------->  panfish
     ||                       ||                         ||                                 ||
     ||                       ||                         ||                                 \/
     ||                       ||                         ||                          [batches up jobs]
     ||                       ||                         ||                                 ||
     ||                       ||                         ||                                 \/
     ||                       ||                         ||                 [sends job files to remote clusters]
     ||                       ||                         ||                                 ||
     ||                       ||                         ||                                 \/ 
     ||                       ||                         ||                  [Submits jobs on remote clusters]
     ||                       ||                         ||                                 ||
     ||                       ||                         ||                                 \/
     ||                       ||                         ||  <--------------[Updates job status upon completion]
     ||                       ||                         \/
     ||                       || <--------------- [Job Completed]
     ||                       \/
     ||  <----------- [returns job status]
     \/                                                   
    User ---> [invokes] ----> qstat
     ||                        ||
     ||                        \/
     ||  <---------- [checks on job status] 
     ||
     \/
    User ---> [invokes] ----> land
     ||                        ||
     \/                        \/
    Done <--------- [pulls data from clusters]


This documentation first lists the key programs then goes into an in depth description
of the actions performed by each program as well, but before all that lets list
the key players along with brief descriptions.

From the user perspective Panfish is composed of the following programs:

User Programs and Configuration files
-------------------------------------

* **cast**                Drop in replacement for **qsub**  This command is responsible
                          for pushing the data for the job to the remote clusters and
                          submitting a shadow job to the local queueing system.

* **land**                Command to retreive data from remote clusters.  Should be
                          invoked after all jobs submitted by **cast** have completed.
       
* **panfish.config**      Configuration file located in the same directory as **cast** and
                          **land**  This file contains information about the remote clusters
                          as well as the submit directory where the shadow jobs put their
                          job files that are picked up by server side of Panfish.
                       


System side Programs
--------------------

* **panfish**             Daemon that runs job files put into the submit directory on
                          appropriate cluster.  The daemon also watches for job
                          completion on the clusters and updates job files status.
                          






panfish.config
--------------

Panfish relies on a configuration file to define information about the remote 
clusters.  That file is named **panfish.config** and is located in the same 
directory as the binaries (cast, land, panfish).

In the configuration file is the following properties in a **key=value** 
format as shown with a real configuration below:

    queue.list=gordon_shadow.q,codonis_shadow.q,trestles_shadow.q,lonestar_shadow.q
    qsub.path=/opt/gridengine/ge6.2u4/bin/lx24-amd64/qsub
    stderr.path=/home/churas/src/panfish/p2/out
    stdout.path=/home/churas/src/panfish/p2/out
    submit.dir=/home/churas/src/panfish/p2/shadow
    job.template.dir=/home/churas/src/panfish/p2/templates


    gordon_shadow.q.host=churas@gordon.sdsc.edu
    gordon_shadow.q.basedir=/projects/ps-camera/gordon/panfish/p2
    gordon_shadow.q.myqsub=/home/churas/gordon/myqsub/myqsubstdin.sh
    gordon_shadow.q.getjobstatus=/home/churas/gordon/myqsub/get_job_status2.pl
    gordon_shadow.q.run.job.script=/home/churas/gordon/myqsub/run_jobs.pl
    gordon_shadow.q.subvar.CAMERA_JAVA=/usr/java/latest/bin/java
    gordon_shadow.q.subvar.CAMERA_SCRATCH_DIR=`/bin/ls /scratch/$USER/[0-9]* -d`

Here is a breakdown of each property:

**queue.list**
    



Step by Step tasks in running a job in Panfish
==============================================

The first step is the creation of a script we will call foo.sh

    #!/bin/bash
    #$PANFISH -dir /home/foo/job
    #$PANFISH -e /home/foo/job/err/$TASK_ID.err
    #$PANFISH -o /home/foo/job/out/$TASK_ID.out

    $PANFISH_BASEDIR/bin/some_command -i $PANFISH_BASEDIR/inputfile.$SGE_TASK_ID -o $PANFISH_BASEDIR/outputfile.$SGE_TASK_ID
   
    if [ $? != 0 ] ; then
       echo "There was an error" 1>&2 
       exit 1
    fi
 
    exit 0

The script resides in **/home/foo/job** folder and the user wishes to run 100 of these jobs on
local and remote clusters.  The user invokes the following:

    $ cast -t 1-100 -q gordon_shadow.q,local_shadow.q,trestles_shadow.q /home/foo/job/foo.sh
    Your job-array 523.1-100:1 ("line") has been submitted 
    $

The **cast** command starts and up parses command line arguments.  The first task
for **cast** is to parse properties file.  **Cast** also examines **foo.sh** for any 
directives.  The directives are defined by **#$PANFISH** prefix.  **Cast** sees 
the **-dir** directive telling it that data needs to be pushed to the remote 
clusters.  Going through the cluster list passed in via **-q** flag **cast** invokes an 
rsync pushing the **-dir** directory to the remote clusters.  The **panfish.properties**
file tells **cast** the base directory and what host to rsync to.
  
Once that is complete **cast** generates the **qsub** call to run shadow jobs which are a program 
named **line**  The **-q** flag is passed as is, so is **-t** flag.  The parameter **-cwd** is added 
and so is **-b** The **qsub** call now invokes the **line** binary giving it the **foo.sh**
script as an argument, along with stderr and stdout file paths as the first two arguments.  

Here is the command generated:

    $ qsub -t 1-100 -b y -cwd -q gordon_shadow.q,local_shadow.q,trestles_shadow.q /home/bin/line /home/foo/job/out/$TASK_ID.out /home/foo/job/err/$TASK_ID.err/home/foo/job/foo.sh
    $



**Cast** then takes the output from **qsub** and outputs it as its own, exiting with the same exit code.  The **line**
program once started will be running in one of the shadow queues.  **Line** looks at what queue it is on by
referring to the **$QUEUE** parameter, it then parses the **panfish.properties** file in the same directory as **line**
for information about that cluster.  

**Line** extracts the following information from the **panfish.properties** file:

* **submit.dir**       This contains the directory path under which there is a folder for each shadow queue
                       All jobs will have a file under these directories and the **line** program will
                       watch job files in here to determine job state.

* **CLUSTER.basedir**  This is the base path on the **CLUSTER** remote file system where panfish will put files under
                       This path will be set as **PANFISH_BASEDIR** variable for executing scripts and all paths
                       should have this as a prefix so files get written correctly on the remote hosts.


 The **line** program generates a file placing it in the submit directory of the
queue matching **$QUEUE.** The submit directory is obtained The file is named **JOB_ID.SGE_TASK_ID.job** where JOB_ID is the SGE job id and SGE_TASK_ID
is the SGE_TASK_ID of the job.  Inside the file is the following line:

    (CURRENT WORKING DIRECTORY)ENDCURRENTDIRexport PANFISH_BASEDIR=\"$PANFISH_BASEDIR\";export SGE_TASK_ID=\"$SGE_TASK_ID\";\$PANFISH_BASEDIR/$CLUSTER_CMD $* > \$PANFISH_BASEDIR/$STDOUTFILE 2> \$PANFISH_BASEDIR/$STDERRFILE"

After writing out the above data to the job file **line** simply waits until that file has the suffix **.failed** or **.done**
exiting with 0 exit code unless **.failed** is the suffix in which case a 1 is returned.  **Line** also watches for a **USR2** signal
which is sent by SGE if the job is deleted.  If this is seen by **line** the program writes out the following to the
standard out file:

    Caught USR2 signal...informing children...exiting...

In addition this text is written to standard out file with a **.killed** suffix:

    Killed by signal

**Line** then exits with code **100**



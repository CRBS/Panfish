
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

    # These properties are cluster specific and will need to
    # be configured for each cluster
    gordon_shadow.q.host=churas@gordon.sdsc.edu
    gordon_shadow.q.basedir=/projects/ps-camera/gordon/panfish/p2
    gordon_shadow.q.myqsub=/home/churas/gordon/myqsub/myqsubstdin.sh
    gordon_shadow.q.getjobstatus=/home/churas/gordon/myqsub/get_job_status2.pl
    gordon_shadow.q.run.job.script=/home/churas/gordon/myqsub/run_jobs.pl
    gordon_shadow.q.subvar.PANFISH_SCRATCH_DIR=`/bin/ls /scratch/$USER/[0-9]* -d`


The above properties can be broken down into two parts.  The first six properties 
above are **global** properties and are used by panfish and line for submission and
monitoring.  The other seven properties seen above are cluster specific and are repeated
for each cluster.  The cluster specific properties will be prefixed with the queue matching
the cluster the jobs should run on.  In the above case **gordon_shadow.q** is the shadow
queue for the **Gordon** cluster.  Another way of saying this is the last seven properties
will be in this format with **CLUSTER** to be replaced by the name of the shadow queue:

    # These properties are cluster specific and will need to
    # be configured for each cluster
    CLUSTER.host=
    CLUSTER.basedir=
    CLUSTER.myqsub=
    CLUSTER.getjobstatus=
    CLUSTER.run.job.script=
    CLUSTER.subvar.PANFISH_SCRATCH_DIR=




Here is a breakdown of each **global** property:

* **queue.list**
    This parameter lists all of the shadow queues configured for panfish.  The cast and land
    commands can optionally have the clusters omitted in which case the data is pushed or pulled
    from all of the clusters in this list.  The list should be comma delimited ideally with no spaces in between.

* **qsub.path** 
    Full path to qsub command on local system that lets Panfish submit the shadow jobs.

* **stderr.path**
    Directory to write the standard error stream for the shadow job.  This output needs to go somewhere
    and is not relevant to the user so we have it written to a special side directory.

* **stdout.path**
    Directory to write the standard output stream for the shadow job.

* **submit.dir**
    Directory where job files created by the line shadow job are written to.  Under this directory is
    a directory with the same name as the cluster queue (ie: gordon_shadow.q/ or codonis_shadow.q)  This property
    is used by line and by Panfish.

* **job.template.dir**
    Directory where job template files for each cluster reside.  The template files are named with the
    same name as the cluster queue (ie: gordon_shadow.q,codonis_shadow.q) For more information see
    Job Template File section of this document.

    Example template for gordon_shadow.q:

      #!/bin/sh
      #
      #PBS -q normal
      #PBS -m n
      #PBS -A ddp140
      #PBS -W umask=0022
      #PBS -o @PANFISH_JOB_STDOUT_PATH@
      #PBS -e @PANFISH_JOB_STDERR_PATH@
      #PBS -V
      #PBS -l nodes=1:ppn=16,walltime=12:00:00
      #PBS -N @PANFISH_JOB_NAME@
      #PBS -d @PANFISH_JOB_CWD@

      /usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@

Here is a breakdown of the **cluster** specific properties

* **CLUSTER.host**
    Host of remote cluster to submit jobs on and to copy data to/from.  This
    should be of the form (user)@(host) ex:  bob@gordon.sdsc.edu

* **CLUSTER.basedir**
    Directory on remote cluster that is considered the base directory under which all
    Panfish jobs will run.  For example, if this is set to /home/foo and a job is run which
    has a path of /home/bob/j1.  The path on the remote cluster would be /home/foo/home/bob/j1.
    This is possible because the job script should prefix all paths with $PANFISH_BASEDIR which 
    will be set to this value.

* **CLUSTER.myqsub**
    Path to myqsub wrapper that handles in job submission as well as offers throttline capability
    because some clusters cannot have more then a limited number of jobs submitted.

* **CLUSTER.getjobstatus**
    Path to qstat wrapper that lets caller get status of job.

* **CLUSTER.run.job.script**
    This script is part of myqsub and lets a set of serial jobs run on a single node in parallel.

* **CLUSTER.subvar.PANFISH_SCRATCH_DIR**
    The temp directory to use for individual jobs on the remote cluster.  Initially this will be
    the only variable that is custom, but in the future any parameter can be set for a given
    cluster by adding another parameter with this format:  CLUSTER.subvar.WHATEVERVARYOUWANT


Step by step list of tasks to run a job in Panfish
=============================================================

cast side
---------

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

The **cast** command starts and up parses command line arguments.  The next task
for **cast** is to parse the **panfish.config** file.  **Cast** also examines **foo.sh** for any 
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


 The **line** program generates a file placing it under in a **queue** directory under the **submit** directory.
The **queue** directory which is set by the **$QUEUE** environment variable.  This variable is set by Grid
Engine to let the running program know what queue is is running under.  The **submit** directory is from
the **panfish.config** file.  The file written is named in this format:  **JOB_ID.SGE_TASK_ID.job** where JOB_ID is the SGE job id and SGE_TASK_ID
is the SGE_TASK_ID of the job.  Inside the file the following is written:

    (CURRENT WORKING DIRECTORY)ENDCURRENTDIRexport PANFISH_BASEDIR=\"$PANFISH_BASEDIR\";export SGE_TASK_ID=\"$SGE_TASK_ID\";\$PANFISH_BASEDIR/$CLUSTER_CMD $* > \$PANFISH_BASEDIR/$STDOUTFILE 2> \$PANFISH_BASEDIR/$STDERRFILE"

**Definition of the above variables which are denoted by ()**

* (CURRENT WORKING DIRECTORY)
    This is the current working directory which is basically the directory the user was located at when they invoked **cast**.

After writing out the above data to the job file **line** simply waits until that file has the suffix **.failed** or **.done**
exiting with 0 exit code unless **.failed** is the suffix in which case a 1 is returned.  **Line** also watches for a **USR2** signal
which is sent by SGE if the job is deleted.  If this is seen by **line** the program writes out the following to the
standard out file:

    Caught USR2 signal...informing children...exiting...

In addition a file with the name set to:  **JOB_ID.SGE_TASK_ID.job.killed** to the same **queue**
directory the job was submitted to is created.  This is to let **Panfish** know the shadow job was deleted.  In
this file the following text is written:

    Killed by signal

**Line** then exits with code **100**

Panfish side
------------

The **Panfish** daemon monitors the cluster/queue directories under the **submit** directory.  The queues to watch
are denoted by the **queue** property.  Panfish has several responsibilities and they are broken into the following
phases; batching of jobs, upload of batched jobs, submission of jobs, and monitoring of running jobs.  The next
sections go into further detail on each of these steps.  All communication between the **line** jobs and **Panfish**
is done through the files put in **queue** directories under the **submit** directory.  **line** watches for certain
file name suffixes to appear to know job state.  At the same time the contents of these files contain information used
by **Panfish** to assist in running the job on the remote cluster.  

Base File name structure:

 **JOB_ID.SGE_TASK_ID.job**

* **JOB_ID** is the Grid Engine job id given to the **line** job when it is submitted to the local cluster

* **SGE_TASK_ID** is the Grid Engine array job id given to the **line** job when it is submitted to the cluster (it maybe unset)

The above file will have the following suffixes that will occur to a job file in this order. 
In addition, the contents of the file will change:

* **.job**
  The job has been put in the directory by **line** and **Panfish** needs to start processing on it.

* **.batched**
  **Panfish** has batched this job with other jobs from the same directory in the **batching of jobs** phase.
  Within the job file a new line is added with this prefix **BATCHEDJOB:::** to the right of this
  keyword the path to the batched job file is written.
  
    Example:  BATCHEDJOB:::/home/foo/j1/gordon_shadow.q/fish.1.8

* **.batchedandchummed**
  **Panfish** has uploaded the batched jobs to the remote cluster in the **upload of batched jobs**

* **.submitted**
  **Panfish** has submitted the job on the remote cluster in the **submission of jobs** phase.

* **.running**
  **Panfish** has updated status to running in the **monitoring of running jobs** phase.

* **.done**
  **Panfish** has updated status to done in the **monitoring of running jobs** phase

**Special case**

* **.failed**
  **Panfish** has failed the job, this can occur in any of the phases.







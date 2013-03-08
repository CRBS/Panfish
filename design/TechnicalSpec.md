Panfish Technical Specification
===============================

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

Panfish takes a script based commandline job and runs that job on a local or remote
cluster.  In addition, Panfish also assists in the serialization and deserialization
of data on those clusters.

Panfish is not a batch processing scheduler on its own, it can be thought of as
a wrapper on top of Sun Grid Engine that handles the logistics of ferrying jobs
to/from remote clusters.    

The benefit of a wrapper is most jobs that work in Sun Grid Engine could in 
theory be run through Panfish with only minimal changes.  Panfish also benefits from
not having to reinvent the wheel when deciding what job to run, that task is left
to Sun Grid Engine.

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

    User ----> [invokes] ----> chum
     ||                         ||
     ||                         \/
     ||  <--------------- [transfers data]
     \/
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


The user first uploads data for the job by calling **chum**  The user
then calls **cast** which submits a shadow job to the local queuing system.  
As part of the submission, is a list of valid shadow queues which 
correspond to remote clusters the job can run under.  The user is given 
the id of the shadow job by the **cast** command.  The user then simply waits 
for those jobs to complete through calls to **qstat**

Grid Engine then schedules the shadow job to an available shadow queue.  
Once the shadow job starts it informs **Panfish** that a job can be run on a 
cluster as defined by the queue the shadow job was run under.  **Panfish** runs 
the job on the remote cluster, and informs the shadow job when the real 
job completes.  

Upon detecting all jobs have completed, the user invokes **land** to retreive
data from all the clusters.

Before any job can run on the remote clusters, the job and its corresponding 
data need to reside there.  Something needs to upload the data and that 
responsibility can be left to the user or to **Panfish** by setting a directive on
the command line or within script saying "hey upload this directory." 

**Panfish** requires all file paths to be prefixed with the environment variable 
**PANFISH_BASEDIR** which will be set appropriately on each cluster, 
(or not set at all if the job ends up locally.)  

For example say we had this job script:

    #!/bin/bash

    echo "Today is: `date`" > /home/foo/j1/thedate.txt

If the above was run on the remote cluster it may fail cause **/home/foo/j1** may not
exist on that cluster.  To deal with this, the job needs to prefix all paths with 
**PANFISH_BASEDIR**  as seen here:

    #!/bin/bash

    echo "Today is: `date`" > $PANFISH_BASEDIR/home/foo/j1/thedate.txt

Now **Panfish** can run the job under an alternate path.

Here is a more in depth diagram denoting the flow of a job through **Panfish**

Diagram of Panfish setup
------------------------
    User ---> [ Sets up password ssh on remote clusters]
     ||
     ||  ---> [invokes] ----------> panfish_setup
     ||                                  ||
     ||                                  \/
     ||                   [asks users questions on clusters] 
     ||                                  ||
     ||                                  \/
     ||  <------- [creates config and uploads/configs remote clusters]
     \/
    User ---> [invokes] ----> panfish_test
     ||                           ||
     ||                           \/
     ||                [creates test job submits] ---> [invokes] ----> Cast/qstat/land
     ||                           ||                                         ||
     ||                           ||                                         \/
     ||                           ||  <------------------------------- [ runs test job]
     ||                           \/
     \/	 <------------[checks success and returns]                                                       
    Done


Diagram of job flow
-------------------
    User ---> [invokes] ----> Chum
     ||                        ||
     ||                        \/
     ||  <------ [uploads data to remote clusters]
     \/                        
    User ---> [invokes] ----> Cast
     ||                        ||
     ||                        \/
     ||          [Invokes qsub on line command]  
     ||                        ||
     ||                        \/
     ||  <------ [returns submitted line job id] ---->  line
     \/                                                  ||
    User ---> [invokes] ---> qstat                       \/
     ||                       ||            [Generates job file based on queue] --------->  Panfish
     ||                       ||                         ||                                 ||
     ||                       ||                         ||                                 \/
     ||                       ||                         ||                          [batches up jobs]
     ||     --------------    ||                         ||                                 ||
     ||    | User is      |   ||                         ||                                 \/
     ||    | calling      |   ||                         ||                   [sends data to remote clusters]
     ||    | qstat        |   ||                         ||                                 ||
     ||    | periodically |   ||                         ||                                 \/ 
     ||     --------------    ||                         ||                  [Submits jobs on remote clusters]
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

* **chum**                Command to upload data to remote clusters.  This command
                          is complemented by **land** which retreives the data.  

* **cast**                Drop in replacement for **qsub**  This command is responsible
                          for submitting a shadow job to the local queueing system.

* **land**                Command to retreive data from remote clusters.  Should be
                          invoked after all jobs submitted by **cast** have completed.

* **panfish_setup**       Assists in configuration of Panfish.

* **panfish_test**        Tool to test Panfish and verify working configuration.

       
* **panfish.config**      Configuration file located in the same directory as **cast** and
                          **land**  This file contains information about the remote clusters
                          as well as the submit directory where the shadow jobs put their
                          job files that are picked up by server side of Panfish.

System side Programs
--------------------

* **panfish**             Daemon that runs job files put into the submit directory on
                          appropriate cluster.  The daemon also watches for job
                          completion on the clusters and updates job files status.  If a job
                          needs to run on the local cluster this daemon also submits it 
                          to whatever Batch processing system is on the cluster.
                          
* **line**                Shadow job that generates a job file and puts it into the
                          submit directory for the appropriate cluster.  The
                          program then watches for the suffix on that job file to 
                          change to either **.failed**, denoting failure, or **.done**
                          denoting successful completion.

* **panfishsubmit**       Takes a list of job files that can be run on the cluster and
                          updates the database so the local **panfish** daemon can submit
                          them to the batch processing system.  

* **panfishstat**         Takes a **panfishsubmit** job file and returns status of the job.

* **panfishrunner**       Runs serial jobs in parallel on a cluster node.

Panfish.config
==============

Panfish relies on a configuration file to define information about the remote 
clusters.  That file is named **panfish.config** and is located in the same 
directory as the binaries (cast, land, panfish).

In the configuration file is the following properties in a **key=value** 
format as shown with a real configuration below:

    cluster.list=gordon_shadow.q,codonis_shadow.q,trestles_shadow.q,lonestar_shadow.q

    # These properties are cluster specific and will need to
    # be configured for each cluster
    gordon_shadow.q.host=churas@gordon.sdsc.edu
    gordon_shadow.q.engine=PBS
    gordon_shadow.q.qsub=/opt/torque/bin/qsub
    gordon_shadow.q.qstat=/opt/torque/bin/qstat
    gordon_shadow.q.job.template.dir=/projects/ps-camera/gordon/panfish/p2/templates
    gordon_shadow.q.line.sleep.time=1
    gordon_shadow.q.line.stderr.path=/projects/ps-camera/gordon/panfish/p2/lineout
    gordon_shadow.q.line.stdout.path=/projects/ps-camera/gordon/panfish/p2/lineout
    gordon_shadow.q.line.log.verbosity=1
    gordon_shadow.q.panfish.log.verbosity=3
    gordon_shadow.q.basedir=/projects/ps-camera/gordon/panfish/p2
    gordon_shadow.q.panfishsubmit=/home/churas/gordon/panfish/panfishsubmit
    gordon_shadow.q.panfishstat=/home/churas/gordon/panfish/panfishstat
    gordon_shadow.q.panfish.job.dir=/home/churas/gordon/panfish/jobs
    gordon_shadow.q.panfish.max.num.jobs=10
    gordon_shadow.q.panfish.submit.sleep=60
    gordon_shadow.q.run.job.script=/home/churas/gordon/panfish/panfishjobrunner
    gordon_shadow.q.scratch=`/bin/ls /scratch/$USER/[0-9]* -d`
    gordon_shadow.q.jobs.per.node=16
    gordon_shadow.q.line.wait=60
    gordon_shadow.q.land.max.retries=10
    gordon_shadow.q.land.wait=100
    gordon_shadow.q.land.rsync.timeout=180
    gordon_shadow.q.land.rsync.contimeout=100


The above properties can be broken down into two parts.  The first six properties 
above are **global** properties and are used by **Panfish** and **line** for submission and
monitoring.  The other seven properties seen above are cluster specific and are repeated
for each cluster.  The cluster specific properties will be prefixed with the queue matching
the cluster the jobs should run on.  In the above case **gordon_shadow.q** is the shadow
queue for the **Gordon** cluster.  Another way of saying this is the last seven properties
will be in this format with **CLUSTER** to be replaced by the name of the shadow queue:

    # These properties are queue specific and will need to
    # be configured for each queue
    CLUSTER.host=
    CLUSTER.qsub=
    CLUSTER.qstat=
    CLUSTER.engine=
    CLUSTER.basedir=
    CLUSTER.panfishsubmit=
    CLUSTER.panfishstat=
    CLUSTER.job.dir=
    CLUSTER.max.num.jobs=
    CLUSTER.submit.sleep=
    CLUSTER.run.job.script=
    CLUSTER.scratch=
    CLUSTER.jobs.per.node=
    CLUSTER.line.wait=
    CLUSTER.land.max.retries=
    CLUSTER.land.wait=
    CLUSTER.land.rsync.timeout=180
    CLUSTER.land.rsync.contimeout=100



Here is a breakdown of each **global** property:

* **cluster.list**
    This parameter lists all of the clusters/queues configured for panfish.  The 
    **cast** and **land** commands can optionally have the clusters omitted in 
    which case the data is pushed or pulled from all of the clusters in this 
    list.  The list should be comma delimited ideally with no spaces in 
    between.


Here is a breakdown of the **queue** specific properties


* **CLUSTER.line.sleep.time**
    Time in seconds the line command should wait between checks on actual job.
    Might want to set this on a per cluster basis cause some clusters are slow
    and others are fast.

* **CLUSTER.line.stderr.path**
    Directory to write the standard error stream for the shadow job.  This
    output needs to go somewhere and is not relevant to the user so we have it
    written to a special side directory.

* **CLUSTER.line.stdout.path**
    Directory to write the standard output stream for the shadow job.

* **CLUSTER.job.template.dir**
    Directory where job template files for each cluster reside.  The template files are named with the
    same name as the cluster queue (ie: gordon_shadow.q,codonis_shadow.q) For more information see
    Job Template File section of this document.

* **CLUSTER.line.log.verbosity**
    Sets the logging level of the line command.  Valid values are 0,1,2,3
    0 = outputs only error,warning, and fatal messages.
    1 = adds info messages.
    2 = adds debug messages.

* **CLUSTER.panfish.log.verbosity**
    Sets the logging level of the panfish daemon.  Valid values are 0,1,2,3
    0 = outputs only error, warning, and fatal messages.
    1 = adds info messages.
    2 = adds debug messages.

* **CLUSTER.host**
    Host of remote cluster to submit jobs on and to copy data to/from.  This
    should be of the form (user)@(host) ex:  bob@gordon.sdsc.edu

* **CLUSTER.qsub**
    Path to qsub program on cluster

* **CLUSTER.qstat**
    Path to qstat program on cluster

* **CLUSTER.engine**
    Batch processing system used by cluster.  Currently PBS, SGE, and GE are supported.

* **CLUSTER.basedir**
    Directory on remote cluster that is considered the base directory under which all
    Panfish jobs will run.  For example, if this is set to /home/foo and a job is run which
    has a path of /home/bob/j1.  The path on the remote cluster would be /home/foo/home/bob/j1.
    This is possible because the job script should prefix all paths with $PANFISH_BASEDIR which 
    will be set to this value.

* **CLUSTER.panfishsubmit**
    Path to **panfishsubmit** wrapper that handles in job submission as well 
    as offers throttline capability because some clusters cannot have more then 
    a limited number of jobs submitted.

* **CLUSTER.panfishstat**
    Path to **panfishstat** wrapper that lets caller get status of job.

* **CLUSTER.job.dir**
    Directory housing filesystem database of jobs.  

* **CLUSTER.max.num.jobs**
    Maximum number of jobs to allow to run concurrently on the cluster.  This
    is done because some clusters restrict # of jobs per user.

* **CLUSTER.submit.sleep**
    Sleep time between submissions.  Some clusters need a break :)

* **CLUSTER.run.job.script**
    This script lets a set of serial jobs run on a single node in parallel.

* **CLUSTER.scratch**
    The temp directory to use for individual jobs on the remote cluster corresponding to the queue.

* **CLUSTER.jobs.per.node**
    The number of serial jobs that can be batched onto one node. 

* **CLUSTER.job.batcher.override.timeout**
    Number of seconds to wait before batching a set of jobs that are
    less then **CLUSTER.jobs.per.node** for the cluster in question.  This
    will result in a submission of a job that does not fully utilize the remote
    compute node hence the delay. 

* **CLUSTER.line.wait**
    Tells **line** command number of seconds to wait before checking if the job file has been renamed.

* **CLUSTER.land.max.retries**
    Number of retries **land** command should make when attempting a retreival of data.

* **CLUSTER.land.wait**
    Number of seconds **land** command should wait between transfer retries.

* **CLUSTER.land.rsync.timeout**
    Sets the rsync IO timeout in seconds. (--timeout)

* **CLUSTER.land.rsync.contimeout**
    Sets the rsync connection timeout in seconds. (--contimeout)


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



Cast
====

This section describes how **Cast** works.  The FunctionalSpec.md has a list of
command line parameters, but here they are again for reference:

    cast [ options (-t,-e, -o, -q) ] [ command -- command args ] 

The **Cast** command is responsible for the submission of a shadow job to the 
local Grid Engine.

Submission of Shadow Job
------------------------

The shadow job is named **line** and it requires the following parameters:
    
    line <stdout path> <stderr path> <script to run> (arguments for script)

**cast** needs to invoke this qsub:

    qsub -notify -b y -cwd -t X -e <shadow stderr path>$JOB_ID.$TASK_ID.err -o <shadow stdout path>.$JOB_ID.$TASK_ID.out line <stdout path> <stderr path> <script to run> (arguments for script)

The **<shadow stderr path>** and **<shadow stdout path>** are obtained from **panfish.config** by parsing
**stderr.path** and **stdout.path** properties.  The **<stdout path>** and **<stderr path>** are parameters
pulled from **-e** and **-o** flags set on the command line to **cast** or as a directive within the 
**<script to run>**

The **<stdout path>** and **<stderr path>** needs to be adjusted before being passed to **qsub**  If the following
variable is found it needs to be swapped like so:

    $TASK_ID  needs to be changed to $SGE_TASK_ID

Due to issues with bash and other shells any variables with **$** prefix may need to be escaped before being
passed to **qsub**.



The **<script to run>** should have all paths prefixed with **$PANFISH_BASEDIR**  Here is an example script
where there are two directives (directives are denoted by starting with #$PANFISH) **-e and -o**  
The directives should **NOT** have the **$PANFISH_BASEDIR** prefix since these paths are only used in the local
system.  

    #!/bin/bash
    #$PANFISH -e /home/foo/job/err/$TASK_ID.err
    #$PANFISH -o /home/foo/job/out/$TASK_ID.out

    $PANFISH_BASEDIR/bin/some_command -i $PANFISH_BASEDIR/inputfile.$SGE_TASK_ID -o $PANFISH_BASEDIR/outputfile.$SGE_TASK_ID

    if [ $? != 0 ] ; then
       echo "There was an error" 1>&2
       exit 1
    fi

    exit 0
 
Outputs
-------

**Cast** should print any output from **qsub**.  In addition, the exit code of **cast**
should match the exit code of **qsub**

If there is an error is should be printed to standard error in this format:

    (seconds since epoch) ERROR (MESSAGE)

Where **(MESSAGE)** is a human readable form of the message.  

If any error is encountered a non-zero exit code should be returned.

Line
====

This section describes how **Line** works.  

The **Line** command is in effect the shadow job run on the local cluster under "shadow" queues.
The arguments for this command can be seen in the **Cast** documentation, but it is repeated here too:

    line <stdout path> <stderr path> <script to run> (arguments for script)

The **Line** program generates a job file and watches for this file to end up in a **done** or **failed**
directory which lets the program know the job has finished or failed.

The file will be named written in the path below with the following format:

**submit.dir/$QUEUE/submitted/$JOB_ID.$TASK_ID**

The **submit.dir** is from the **panfish.config** file and the variables **$QUEUE, $JOB_ID, and $TASK_ID** 
are set by Grid Engine and define the queue the job is running under and its job id and task id.  
If $TASK_ID is NOT set which is possible if the user submitted a single job then the **.$TASK_ID** 
from the job file name.

Example files where **submit.dir** = /home/foo and $QUEUE = lion_shadow


Job id is 456 and task id is 1:

* **/home/foo/lion_shadow/submitted/456.1**

Job id is 5555 and task id is not set:

* **/home/foo/lion_shadow/submitted/5555

In the job file the following data will be written by the **line** command:

    current.working.dir=(CURRENT WORKING DIRECTORY)
    job.name=(JOB NAME)
    command.to.run=(COMMAND TO RUN)

* (CURRENT WORKING DIRECTORY)

** This is the current working directory where the **line** command was invoked from.  This is 
set by Grid Engine. ex:  /home/foo/job1

* (JOB NAME)

** Should be set to **$JOB_NAME** set in the **line** job by the **cast** command.  This is an option that is set
   by the caller.

* (COMMAND TO RUN)

** This is the command to run on the remote cluster.  The command needs to be formatted in the following
way:
  export PANFISH_SCRATCH="<panfish.config::[CLUSTER].scratch>";export PANFISH_BASEDIR="<panfish.config::[CLUSTER].basedir>";export JOB_ID="<$JOB_ID>";export SGE_TASK_ID="<$TASK_ID>";$PANFISH_BASEDIR/<script to run> (arguments for script) > $PANFISH_BASEDIR/<stdout path> 2> $PANFISH_BASEDIR/<stderr path>

Basically what is happening is we are generating a job where **PANFISH_BASEDIR**, **PANFISH_SCRATCH**, 
**PANFISH_JOB_ID**, and **PANFISH_TASK_ID** variables are set to correct values.  In addition, 
the standard error and standard out files are set appropriately.  This job can now be easily run 
on remote clusters by the **Panfish** daemon.

Here is a breakdown of the variables in the line above which are denoted by **<>**

<panfish.config::[CLUSTER].basedir>
  This is the basedir parameter from the **panfish.config** where CLUSTER is set to $QUEUE variable in the **line** command.
  For instance, if the **line** job ended up in **foo.q** then $QUEUE would be set to **foo.q** and the **line** program
  should look for **foo.q.basedir** in the **panfish.config**

<$JOB_ID>
  This is the $JOB_ID set by Grid Engine in the **line** job.  It should always be set.

<$TASK_ID>
  This is the $TASK_ID set by Grid Engine in the  **line** job. It will either be an empty string or a number.

<script to run>
  This is the script to run passed into the **line** command.  

(arguments for script)
  These are the command line arguments for the script passed into the **line** command.  They should just
  be passed into the script with one exception.  Any $PANFISH_BASEDIR variables need to have $ escaped
  so the prefix is set properly.  It is still up to the caller to prefix any path with $PANFISH_BASEDIR.

Example job file:

    submitter=line
    current.working.dir=/home/foo/job1
    job.name=frodo_blast
    command.to.run=export PANFISH_BASEDIR="/projects/foo";export JOB_ID="345";export SGE_TASK_ID="12";$PANFISH_BASEDIR/home/foo/job1/runjob.sh -somearg 1 -somearg 2 > $PANFISH_BASEDIR/home/foo/job1/stdout/runjob.$SGE_TASK_ID.out 2> $PANFISH_BASEDIR/home/foo/job1/stderr/runjob.$SGE_TASK_ID.err

In the above case **/home/foo/job1** is the directory on the local system where the job is based and the script is
within that directory named **runjob.sh** the path **/projects/foo** is the base directory on the remote cluster.  The job
will now be run under **/projects/foo/home/foo/job1** on that cluster.  


The **line** program should now sit in a wait loop waiting **panfish.config::[CLUSTER].linewait** seconds
before checking if file has moved to **done** or **failed** directory.   **line** should also watch
for USR1, USR2, and TERM signals and if received the program should write out the job file to

    <panfish.config::cluster.job.dir>/$QUEUE/kill

before exiting with 50 as an exit code and a log message to standard error and out.  The above
lets **Panfish** know that the real job should be killed.

Outputs
-------

The **line** program should output the following to standard out:

    (seconds since epoch) INFO User:  (User line is running as)
    (seconds since epoch) INFO Queue:  (Queue job is on)
    (seconds since epoch) INFO Command:  (Arguments passed to line command)
    (seconds since epoch) INFO Wait Interval:  (# seconds to wait between checks)
    (seconds since epoch) INFO Job File:  (Full path to job file)

If log level is **DEBUG** then each status check should be logged as follows:

    (seconds since epoch) DEBUG State of job:  (submitted, batched, batchedandchummed, running)

If log level is **INFO** then only log state changes:

    (seconds since epoch) INFO State change from (old) to (submitted, batched, batchedandchummed, running, failed)

Upon completion log this:

    (seconds since epoch) INFO Job Completed.

Any errors should be logged to standard error and should follow the above logic with ERROR
in the log level.

   
Land
====

This program lets caller retreive data from remote clusters via rsync call.  
The command line parameters are in this format:

    land (options) (directory path)
    
The **land** program is given a directory path and possibly a queue/cluster.  With this information
**line** will retreive the directory passed in from all remote clusters, in order seen in queue.list
parameter in **panfish.config** or from just the cluster specified.  This is done by using rsync
and the basedir for the corresponding cluster in the config is prefixed to the path on the remote side. 


**Line** should have logic to retry if a rsync call fails.  <panfish.config::[CLUSTER].land.max.retries> and
<panfish.config::[CLUSTER].land.wait> should be used by the **line** command to determine
number of retries and delay to wait between those retries.  Although these values can be overridden via
command line options **--retry** and **--retryTimeout**  Don't forget there is also a **--dry-run** flag
to not perform the transfer just talk about it.  

Base rsync call:
    rsync -rtpz --stats --timeout=X --contimeout=Y -e ssh

The arguments above: **-rtpz** denotes recursive, compressed transfer preserving time stamps and permissions.
The X should be pulled from <panfish.config::[CLUSTER].land.rsync.timeout> and
Y should be pulled from <panfish.config::[CLUSTER].land.rsync.contimeout>.

Before doing the transfer perform a calculation of data to download.  One easy way to do this, but
with some risk is the **du** command on the directory to download.  After calculating data to transfer
this value is output to the user along with transfer rate which can be calculated by dividing data
size by duration of transfer.  

Outputs
-------

Upon success zero exit code will be output.

Text output from transfers will be in this format:

Downloading... XX bytes from YYY...Complete Rate:  ZZ mb/sec.
Downloading... XX bytes from YYY...Complete Rate:  ZZ mb/sec.

Where XX is size of data to retreive.  YYY is the cluster data is pulled
from and ZZ is the transfer rate calculated by taking XX bytes divided
by the time to transfer.

Any errors should be logged as follows:

(seconds since epoch) ERROR (MESSAGE)

with non zero exit code.


Panfish_setup
=============

This program helps the user add, configure, and remove clusters from Panfish.  This is
done by adjusting **panfish.config** and **panfishsubmit.config** as well as uploading
binaries and other data to remote clusters. 


Panfish_test
============

This program lets the user run a test to verify correct configuration of Panfish.  It can
also be used as a "heartbeat" tool to verify correct operation of clusters.  

Panfish
=======

The **Panfish** daemon monitors the cluster/queue directories under the **submit** directory.  The queues to watch
are denoted by the **queue** property.  Panfish has several responsibilities and they are broken into the following
phases; batching of jobs, upload of batched jobs, submission of jobs, and monitoring of running jobs.  The next
sections go into further detail on each of these steps.  All communication between the **line** jobs and **Panfish**
is done through the files put in **queue** directories under the **submit** directory.  **line** watches for certain
file name suffixes to appear to know job state.  At the same time the contents of these files contain information used
by **Panfish** to assist in running the job on the remote cluster.  

Command line:

    Panfish (options)

**(options)**

* **--cluster**  Specifies the cluster this panfish daemon is running on.

* **--log**      Specifies path to log file

* **--conf**     Specifies path to **panfish.config** file

* **--daemon**   Tells **Panfish** to run in daemon mode, that is
                 set base directory to / and send stderr/stdout to dev null
                 and run in a loop.  This should be invoked via etc/init.d script.

Base File name structure:

 **JOB_ID.SGE_TASK_ID.job**

* **JOB_ID** is the Grid Engine job id given to the **line** job when it is submitted to the local cluster

* **SGE_TASK_ID** is the Grid Engine array job id given to the **line** job when it is submitted to the cluster (it maybe unset)

The subdirectory in which the above job file is placed defines the state of the job.  Under each
**job.dir** directory the following directories need to exist:


* **submitted**
  Job has been submitted by one of three programs which is defined by **submitter** property in
  job file.  
  **line**  Means job was submitted as a shadow job by **cast** command.  Jobs with this source
            go through batched,batchedandchummed states then onto queued, running,done.

  **panfishsubmit** Means a **panfish** daemon has submitted this job to be run directly on
                    batch processing system for the cluster the job file resides in.  These
                    jobs move next to queued when they are submitted to cluster for invocation.

* **batched**
  **Panfish** has batched this job with other jobs from the same directory in the **batching of jobs** phase.
  Within the job file a new line is added with this prefix **commands.file=** to the right of this
  keyword the path to the batched job file is written.  In addition the **psub** file should also
  be added to the job file.
  
    Example:  
            commands.file=/home/foo/j1/gordon_shadow.q/1.8.commands
            psub.file=/home/foo/j1/gordon_shadow.q/1.8.psub

* **batchedandchummed**
  **Panfish** has uploaded the batched jobs to the remote cluster in the **upload of batched jobs**

* **queued**
  **Panfish** has submitted the job for processing on local or remote clusters via a call to **panfishsubmit**

* **running**
  **Panfish** has updated status to running in the **monitoring of running jobs** phase.

* **done**
  **Panfish** has updated status to done in the **monitoring of running jobs** phase.

**Special case**

* **failed**
  **Panfish** has failed the job, this can occur in any of the phases.


**Panfish** is actually a collection of what could be considered several separate
programs.  For now this work will just be done in one daemon in a single threaded
program, but could easily be split up.  In the next sections the main pieces of
the application will be described.  


Going from submitted to queued for **panfishsubmit** source jobs
----------------------------------------------------------------

The **submitted** directory does a double duty here.  Jobs that have a **submitter**
type of panfishsubmit are jobs that have already come from a shadow job and just need
to be run on the cluster.  These jobs should only show up in this folder for the cluster
the panfish daemon is running on.  **Panfish** should again invoke **panfishsubmit** on this
job to submit the job for real to the local cluster.  **panfishsubmit** will append a **real.job.id**
property to the job file as it moves the job to **queued** state

Going from submitted to batched for **line** source jobs
--------------------------------------------------------

This is the initial phase of the job and **Panfish**'s job is to look for a 
list of files within a given **CLUSTER/submitted** directory that share the 
same **JOB_ID** AND have a **submitter** of type **line**. 
These files are sorted by **SGE_TASK_ID** in ascending order 
   These files are then put into batches based on number of cores each
node has on the cluster corresponding to the **CLUSTER** for the job.  Any extra job
files are left unless the files are over X seconds old in which case they get
their own batch.  

Once the batches are figured out they are written to files known as **COMMAND** files with 
the name:  **$JOB_ID.(MIN SGE_TASK_ID).commands** 

**$JOB_ID** is the id of the job and can be parsed from the **.job** file and
**(MIN SGE_TASK_ID)** is the smallest **$SGE_TASK_ID** in the batch.  

The **COMMAND** file is written to:
**current.working.dir/CLUSTER** directory.  **Panfish** will need to create this **CLUSTER** directory
if it does not exist.  

Another file that is actually submitted to the remote clusters queueing system.  This file for
a lack of a better name is known as **PSUB** file and is created by using the template file
corresponding to the **CLUSTER** the job files ended up in.  This template file needs the following
tokens replaced:

    @PANFISH_JOB_STDOUT_PATH@     -- Set to current.working.dir/CLUSTER/JOBFILE.stdout
    @PANFISH_JOB_STDERR_PATH@     -- Set to current.working.dir/CLUSTER/JOBFILE.stderr
    @PANFISH_JOB_NAME@            -- Set to job.name in job file submitted by line command.
    @PANFISH_JOB_CWD@             -- Set to CLUSTER.basedir/current.working.dir
    @PANFISH_RUN_JOB_SCRIPT@      -- Set to <panfish.config::[CLUSTER].run.job.script>
    @PANFISH_JOB_FILE@            -- Set to fish.$JOB_ID.(MIN SGE_TASK_ID).command file path

This file is given the same name as the **COMMAND** file, but with **.psub** added as suffix. 
This **.psub** file should be given execute permission.

See **Job template files and directory** section for more information on template files.

After writing the **.psub** file the original file should have the following
line added:
    commands.file=(PATH TO COMMANDS file)
    psub.file=(PATH TO PSUB file)

The psub file should also be made user/group executable.

and the file should be moved to **CLUSTER/batched** directory



Going from batched to batchedandchummed
---------------------------------------

In this phase the batched jobs are uploaded to appropriate remote clusters.

Step one in this phase is to find all the files in **CLUSTER/batched** and get a unique list of 
**current.working.dir** paths.  For each of these paths upload the 
**current.working.dir/CLUSTER** directory.  Once uploaded the suffix of each file should
be moved to **CLUSTER/batchedandchummed**


Going from batchedandchummed to queued
-------------------------------------------

In this phase the jobs are queued up by **panfishsubmit** to the remote cluster.

Step one in this phase is to look for all files to get a unique
list of **.psub** files.  These **.psub** file paths should be prefixed with the remote
cluster **<panfish.config::[CLUSTER].basedir>** and passed to standard in of 
**<panfish.config::[CLUSTER].psub>** command.  **panfishsubmit** will output job ids that
match the job file.  

and the files should be moved to **CLUSTER/queued** directory.  


Going from queued/running to failed or done
---------------------------------

In this phase the jobs are on the remote cluster or local and just need to get their status.

In this phase look for all jobs in **queued or running** and simply pass these jobs to **<panfish.config::[CLUSTER].panfishstat>**
via standard in to get the job status.  The status of the jobs should be updated.


Job template Files and Directory
================================

Each remote cluster has a set of directives and configuration options
that must be set.  To handle this mismatch there should be a template job
file for each **CLUSTER** in the **<panfish.config::job.template.dir>** which
will set all the correct options for that cluster.  Below are a couple
example template files:


Example PSUB file for PBS:
--------------------------

     #!/bin/sh
     #
     #PBS -q bs_primary
     #PBS -m n
     #PBS -W umask=0022
     #PBS -o @PANFISH_JOB_STDOUT_PATH@
     #PBS -e @PANFISH_JOB_STDERR_PATH@
     #PBS -V
     #PBS -l nodes=1:ppn=18,walltime=12:00:00
     #PBS -N @PANFISH_JOB_NAME@
     #PBS -d @PANFISH_JOB_CWD@

     /usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@

In the above case the template file says there are 18 cores a node and a job can only run
for 12 hours.  The queue is set to **bs_primary**


Example PSUB file for Grid Engine:
----------------------------------

    #!/bin/sh
    #$ -S /bin/sh
    #$ -V
    #$ -cwd
    #$ -o @PANFISH_JOB_STDOUT_PATH@
    #$ -e @PANFISH_JOB_STDERR_PATH@
    #$ -N @PANFISH_JOB_NAME@
    #$ -q all.q
    #$ -l h_rt=12:00:00

    /usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@

In the above case the queue is set to **all.q** and runtime is set to 12 hours
and with no other setting each job gets only 1 core.

panfishsubmit
=============

panfishsubmit --cluster (cluster name)

This program is given **commands** to run via standard in (one per line) and should do one of two things.
If the command passed in has a .psub suffix then this is a request from a remote cluster and a job should be created 
and put in the **submitted** state with **submitter** set to panfishsubmit and psub file is set within as well.  






These job files known as **psub job files**.
  

Inside the **psub job file** is this content:

    current.working.dir=(CURRENT WORKING DIR)
    command.to.run=(COMMAND AND ARGUMENTS)

**psub** sets the **(CURRENT WORKING DIR)** to the directory **psub** was
invoked from.  The **(COMMAND AND ARGUMENTS)** come either from standard in or
from the command line arguments.  If the first argument passed to **psub** is **-**
then **psub** should read from standard in and consider each line a new job file. 

Output should be as follows:

     $ psub (command file)
     (command filename only .psub suffix removed)
     $

For invocation with **-** flag read from standard in and output as follows:

     $ echo -e "(command1)\\n(command2)" | psub -
     (command1 filename only .psub suffix removed)
     (command2 filename only .psub suffix removed)
     $

If **(command)** already exists in the **<psubmitter.config::psub.dir>>**
consider this an error and exit with non zero exit code. 

In batch mode first command to fail should cause whole command to fail.



panfishstat
===========

This program takes a **panfishsubmit job id** output from **panfishsubmit** and returns the job's
status by looking in the **<panfishsubmit.config::panfishsubmit.dir>** for the job
file and based on the directory it resides in is the state returned.

panfishstat [ panfishsubmit job id | - ]

**panfishsubmit job id    **    Should be a job id output from **panfishsubmit** OR
                             **-** which tells **pstat** to read from standard in.

Output will be in this format:

    ###.#:::(STATUS)

Where **###.#** is the job id from **psub** and **(STATUS)** is the status
of the job which can be one of the following:

**notfound**      Job not found.

**queued**        Job is queued.

**submitted**     Job is submitted to **panfishsubmitd**

**running**       Job is running.

**failed**        Job failed.

**done**          Job done.


Example invocation passing **psub job file** as an argument:

     $ pstat 499.6
     499.6:::done
     $

Example invocation passing **psub job files** via standard in:

     $ echo "482.5\\n499.6\\n435.4" | pstat -
     482.5:::running
     499.6:::done
     435.4:::failed
     $

Any errors should have ERROR:  prefixed and a non zero exit code.

The **panfish submit directory** looks like this:

    .
    ..
    submitted/
    queued/
    running/
    done/
    failed/

**panfishstat** should return the name of the directory as the state of the job. 


panfishsubmitd
==============

This is a program run as a cron once a minute or so on the remote cluster
and it watches the **<panfishsubmit.config::panfishsubmit.dir>** sub directories
for jobs, submitting them to the batch processing system for the cluster as
well as updating status of all other job files found in any state other then
**completed** and **failed**

The program should verify only one instance of itself is running by creating
a pid file and verifying the pid within is its own otherwise it should exit.

After verifying it is the only instance running it should get a current list
of running jobs on the cluster.  This can be done with **qstat** this list should
also be used to count the number of running/queued jobs the current user has.

Next under each of the following directories:
     queued/
     running/
     
Look at all job files and build a hash of **job_id** => file.name and use
the output of **qstat** to move the job files to appropriate file if state
changed.  

Example PBS output from qstat:

     $ qstat
     Job id                    Name             User            Time Use S Queue
     ------------------------- ---------------- --------------- -------- - -----
     550174.gordon-fe2         ...DFT.gordonjob kmorgan                0 Q normal         
     550179.gordon-fe2         ...32x16_hop1.sh syazaki                0 E normal         
     550186.gordon-fe2         STDIN            sinkovit        00:00:02 R normal         
     550188.gordon-fe2         run              nukenk          00:00:00 C normal         
     $

I think that is all the possible states above.

Example SGE output from qstat:

     $ qstat -u "*"
     job-ID  prior   name       user         state submit/start at     queue                          slots ja-task-ID 
     -----------------------------------------------------------------------------------------------------------------
     1016023 0.52489 gaussian1  bonbon       dr    02/09/2013 09:18:50 gpu@c300-214.ls4.tacc.utexas.e    12        
     1017660 0.52514 hadgem.a1b khayhoe      r     02/11/2013 12:02:50 normal@c316-305.ls4.tacc.utexa   468        
     1012888 0.50180 bliss_job  melrom       Eqw   02/07/2013 20:10:21                                   12
     1023673 0.00000 oases_merg benni        hqw   02/12/2013 17:09:52                                   12        
     1023686 0.00000 PLTAD_II_R kv147        qw    02/12/2013 17:13:16                                   12        

The states can also be **s, or S and possibly sql, and have a t in it too**


Now if a job has completed **C** or no longer exists in the list, be sure to check 
standard error and standard output files exist on the filesystem and both have a filesize
greater then 0, if not something failed so put the job file in the failed directory.

The standard error and standard output files can be found by reading directives in in **psub** file in 
command submitted.  If not there don't do the check.


In addition, look in the standard error file and any output outside ^real or ^user ^sys is a failure.

Once this is completed now look at **<psubmitter.config::max.num.jobs>** and if current
running jobs is above this threshold then exit logging:

     (seconds since epoch) DEBUG # jobs running exceeding <psubmitter.config::max.num.jobs> threshold. exiting..

If below threshold look in **submitted** directory for any job files.
Sort the job files oldest to newest and in a loop open each job file
using the current working directory and command to submit the job using
**qsub** or whatever the scheduler uses.  Set the job name to the name
of the job file prefixing it with a x if necessary.
Upon submission take job id and append this line to the job file:

     job.id=(ID of job from qsub)

After adjusting the file move it to **queued** folder or **failed** if there was a problem.


**PROBLEM:  what if a job already has job.id file as in case of being killed mid submit?**

Be sure to sleep in between submits **<panfishsubmit.config::submit.sleep>** 

Once this is all done. exit...



panfishrunner
=============

This program is a helper program to run batched serial jobs on a compute node.  

Command line:

     panfishrunner (options) <file with list of programs to run. 1 per line>

(options)

     For now no options, but we may want to add a feature where the caller can
     say run only 12 jobs concurrently and start new ones from the file as others
     finish.  This would let us run really fast serial jobs more efficiently.  


This program should read the file given to it and invoke each command in parallel and
wait for the commands to exit.  If any commands exit, this command should exit with non zero
exit code and log an error to standard error with format:

    ERROR: (command) : Non-zero exit code: #

Otherwise write to standard out when a parallel job starts and when it finishes along with 
any other pertinent information.  

panfishsubmit.config
====================

This configuration file will reside in the same directory as the **panfishsubmit**, **panfishstat**, and
**panfishsubmit** binaries and will contain the following fields:

     panfishsubmit.dir=Directory where job files will be put by psub

     max.num.jobs=Maximum # of jobs to submit to batch processing system 

     submit.sleep=Wait time in seconds between submission of jobs to batch processing system


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
to the local queuing system.  As part of the submission is a list of valid
shadow queues which correspond to remote clusters the job can run
under.  The user is given the id of the shadow job by the **cast** command.  
The user then simply waits for those jobs to complete through calls to **qstat**

Grid Engine then schedules the shadow job to an available shadow queue.  
Once the shadow job starts it informs **Panfish** that a job can be run on a 
cluster as defined by the queue the shadow job was run under.  **Panfish** first
optionally uploads data, runs the job on the remote cluster, and informs the shadow job 
when the real job completes.  

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


Diagram of flow
---------------

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

* **cast**                Drop in replacement for **qsub**  This command is responsible
                          for submitting a shadow job to the local queueing system.

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
                          
* **line**                Shadow job that generates a job file and puts it into the
                          submit directory for the appropriate cluster.  The
                          program then watches for the suffix on that job file to 
                          change to either **.failed**, denoting failure, or **.done**
                          denoting successful completion.

* **psub**                Submits command to **psub_mitter** which submits the
                          job to the remote cluster.  Outputs a job file which 
                          can be used to monitor command status.
             

* **pstat**               Takes a **psub** job file and returns status of the job.

* **psub_mitter**         Daemon that submits **psub** jobs to remote cluster.

Panfish.config
==============

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
    gordon_shadow.q.psub=/home/churas/gordon/psub/psub
    gordon_shadow.q.pstat=/home/churas/gordon/psub/pstat
    gordon_shadow.q.run.job.script=/home/churas/gordon/psub/run_jobs
    gordon_shadow.q.scratch=`/bin/ls /scratch/$USER/[0-9]* -d`
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
will be in this format with **QUEUE** to be replaced by the name of the shadow queue:

    # These properties are queue specific and will need to
    # be configured for each queue
    QUEUE.host=
    QUEUE.basedir=
    QUEUE.psub=
    QUEUE.pstat=
    QUEUE.run.job.script=
    QUEUE.scratch=
    QUEUE.line.wait=
    QUEUE.land.max.retries=
    QUEUE.land.wait=
    QUEUE.land.rsync.timeout=180
    QUEUE.land.rsync.contimeout=100



Here is a breakdown of each **global** property:

* **queue.list**
    This parameter lists all of the shadow queues configured for panfish.  The 
    **cast** and **land** commands can optionally have the clusters omitted in 
    which case the data is pushed or pulled from all of the clusters in this 
    list.  The list should be comma delimited ideally with no spaces in 
    between.

* **qsub.path** 
    Full path to **qsub** command on local system that lets **Panfish** submit 
    the shadow jobs.

* **stderr.path**
    Directory to write the standard error stream for the shadow job.  This 
    output needs to go somewhere and is not relevant to the user so we have it 
    written to a special side directory.

* **stdout.path**
    Directory to write the standard output stream for the shadow job.

* **submit.dir**
    Directory where job files created by the line shadow job are written to.  
    Under this directory is a directory with the same name as the cluster queue 
    (ie: gordon_shadow.q/ or codonis_shadow.q)  This property is used by line 
    and by **Panfish**.

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

Here is a breakdown of the **queue** specific properties

* **QUEUE.host**
    Host of remote cluster to submit jobs on and to copy data to/from.  This
    should be of the form (user)@(host) ex:  bob@gordon.sdsc.edu

* **QUEUE.basedir**
    Directory on remote cluster that is considered the base directory under which all
    Panfish jobs will run.  For example, if this is set to /home/foo and a job is run which
    has a path of /home/bob/j1.  The path on the remote cluster would be /home/foo/home/bob/j1.
    This is possible because the job script should prefix all paths with $PANFISH_BASEDIR which 
    will be set to this value.

* **QUEUE.psub**
    Path to **psub** wrapper that handles in job submission as well as offers throttline capability
    because some clusters cannot have more then a limited number of jobs submitted.

* **QUEUE.pstat**
    Path to **pstat** wrapper that lets caller get status of job.

* **QUEUE.run.job.script**
    This script lets a set of serial jobs run on a single node in parallel.

* **QUEUE.scratch**
    The temp directory to use for individual jobs on the remote cluster corresponding to the queue.

* **QUEUE.line.wait**
    Tells **line** command number of seconds to wait before checking if the job file has been renamed.

* **QUEUE.land.max.retries**
    Number of retries **land** command should make when attempting a retreival of data.

* **QUEUE.land.wait**
    Number of seconds **land** command should wait between transfer retries.

* **QUEUE.land.rsync.timeout**
    Sets the rsync IO timeout in seconds. (--timeout)

* **QUEUE.land.rsync.contimeout**
    Sets the rsync connection timeout in seconds. (--contimeout)

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

    qsub -t X -e <shadow stderr path>$JOB_ID.$TASK_ID.err -o <shadow stdout path>.$JOB_ID.$TASK_ID.out line <stdout path> <stderr path> <script to run> (arguments for script)

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
where there are three directives (directives are denoted by starting with #$PANFISH) **-dir, -e, and -o**  
The directives should **NOT** have the **$PANFISH_BASEDIR** prefix since these paths are only used in the local
system.  

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

The **Line** program generates a job file and waits for the suffix on that job file to switch to
**.done** or **.failed** 

The file will be named written in the path below with the following format:

**submit.dir/$QUEUE/$JOB_ID.$TASK_ID.job**

The **submit.dir** is from the **panfish.config** file and the variables **$QUEUE, $JOB_ID, and $TASK_ID** 
are set by Grid Engine and define the queue the job is running under and its job id and task id.  

Example files where **submit.dir** = /home/foo and $QUEUE = lion_shadow


Job id is 456 and task id is 1:

* **/home/foo/lion_shadow/456.1.job**

Job id is 5555 and task id is not set:

* **/home/foo/lion_shadow/5555..job

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
  export PANFISH_SCRATCH="<panfish.config::[QUEUE].scratch>";export PANFISH_BASEDIR="<panfish.config::[QUEUE].basedir>";export JOB_ID="<$JOB_ID>";export SGE_TASK_ID="<$TASK_ID>";$PANFISH_BASEDIR/<script to run> (arguments for script) > $PANFISH_BASEDIR/<stdout path> 2> $PANFISH_BASEDIR/<stderr path>

Basically what is happening is we are generating a job where **PANFISH_BASEDIR**, **PANFISH_SCRATCH**, 
**PANFISH_JOB_ID**, and **PANFISH_TASK_ID** variables are set to correct values.  In addition, 
the standard error and standard out files are set appropriately.  This job can now be easily run 
on remote clusters by the **Panfish** daemon.

Here is a breakdown of the variables in the line above which are denoted by **<>**

<panfish.config::[QUEUE].basedir>
  This is the basedir parameter from the **panfish.config** where QUEUE is set to $QUEUE variable in the **line** command.
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

    current.working.dir=/home/foo/job1
    job.name=frodo_blast
    command.to.run=export PANFISH_BASEDIR="/projects/foo";export JOB_ID="345";export SGE_TASK_ID="12";$PANFISH_BASEDIR/home/foo/job1/runjob.sh -somearg 1 -somearg 2 > $PANFISH_BASEDIR/home/foo/job1/stdout/runjob.$SGE_TASK_ID.out 2> $PANFISH_BASEDIR/home/foo/job1/stderr/runjob.$SGE_TASK_ID.err

In the above case **/home/foo/job1** is the directory on the local system where the job is based and the script is
within that directory named **runjob.sh** the path **/projects/foo** is the base directory on the remote cluster.  The job
will now be run under **/projects/foo/home/foo/job1** on that cluster.  

The **line** program should write out the file first without a .job suffix and then rename it.  This
will minimize race conditions between the **Panfish** daemon and **line**  

The **line** program should now sit in a wait loop waiting **panfish.config::[QUEUE].linewait** seconds
before checking if file now has **.failed** or **.done** status.  

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

    line (options) (directory path) (optional queue/cluster)
    
The **line** program is given a directory path and possibly a queue/cluster.  With this information
**line** will retreive the directory passed in from all remote clusters, in order seen in queue.list
parameter in **panfish.config** or from just the cluster specified.  This is done by using rsync
and the basedir for the corresponding cluster in the config is prefixed to the path on the remote side. 


**Line** should have logic to retry if a rsync call fails.  <panfish.config::[QUEUE].land.max.retries> and
<panfish.config::[QUEUE].land.wait> should be used by the **line** command to determine
number of retries and delay to wait between those retries.  Although these values can be overridden via
command line options **--retry** and **--retryTimeout**  Don't forget there is also a **--dry-run** flag
to not perform the transfer just talk about it.  

Base rsync call:
    rsync -rtpz --stats --timeout=X --contimeout=Y -e ssh

The arguments above: **-rtpz** denotes recursive, compressed transfer preserving time stamps and permissions.
The X should be pulled from <panfish.config::[QUEUE].land.rsync.timeout> and
Y should be pulled from <panfish.config::[QUEUE].land.rsync.contimeout>.

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


Panfish side
============

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

* **--log**      Specifies path to log file

* **--conf**     Specifies path to **panfish.config** file

* **--daemon**   Tells **Panfish** to run in daemon mode, that is
                 set base directory to / and send stderr/stdout to dev null
                 and run in a loop.  This should be invoked via etc/init.d script.

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
  
    Example:  BATCHEDJOB:::/home/foo/j1/gordon_shadow.q/fish.1.8.commands

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


**Panfish** is actually a collection of what could be considered several separate
programs.  For now this work will just be done in one daemon in a single threaded
program, but could easily be split up.  In the next sections the main pieces of
the application will be described.  


Going from .job to .batched
---------------------------

This is the initial phase of the job and **Panfish**'s job is to look for a 
list of **.job** files within a given **QUEUE** directory that share the 
same **JOB_ID**.  These **.job** files are sorted by **SGE_TASK_ID** in 
ascending order.  
   These **.job** files are then put into batches based on number of cores each
node has on the cluster corresponding to the QUEUE for the job.  Any extra job
files are left unless the files are over X seconds old in which case they get
their own batch.  

Once the batches are figured out they are written to files known as **COMMAND** files with 
the name:  **fish.$JOB_ID.(MIN SGE_TASK_ID).command** 

**$JOB_ID** is the id of the job and can be parsed from the **.job** file and
**(MIN SGE_TASK_ID)** is the smallest **$SGE_TASK_ID** in the batch.  

The **COMMAND** file is written to:
**current.working.dir/QUEUE** directory.  **Panfish** will need to create this **QUEUE** directory
if it does not exist.  

Another file that is actually submitted to the remote clusters queueing system.  This file for
a lack of a better name is known as **PSUB** file and is created by using the template file
corresponding to the **QUEUE** the job files ended up in.  This template file needs the following
tokens replaced:

    @PANFISH_JOB_STDOUT_PATH@     -- Set to current.working.dir/QUEUE/JOBFILE.stdout
    @PANFISH_JOB_STDERR_PATH@     -- Set to current.working.dir/QUEUE/JOBFILE.stderr
    @PANFISH_JOB_NAME@            -- Set to job.name in job file submitted by line command.
    @PANFISH_JOB_CWD@             -- Set to QUEUE.basedir/current.working.dir
    @PANFISH_RUN_JOB_SCRIPT@      -- Set to <panfish.config::[QUEUE].run.job.script>
    @PANFISH_JOB_FILE@            -- Set to fish.$JOB_ID.(MIN SGE_TASK_ID).command file path

This file is given the same name as the **COMMAND** file, but with **.psub** added as suffix. 
This **.psub** file should be given execute permission.

See **Job template files and directory** section for more information on template files.



After writing the **PSUB** file the original **.job** file should have the following
line added:

    psub.file=(PATH TO PSUB file)

and the **.job** file should have the suffix **.batched** appended.

This completes this phase.


Going from .batched to .batchedandchummed
-----------------------------------------

In this phase the batched jobs are uploaded to appropriate remote clusters.

Step one in this phase is to find all the **.batched** files and get a unique list **current.working.dir**
paths.  For each of these paths upload the **-dir** path if set otherwise just push up the **current.working.dir/QUEUE**
directory.  Once uploaded the suffix of each **.batched** file should
be switched to **.batchedandchummed**



Going from .batchedandchummed to .submitted
-------------------------------------------

In this phase the jobs are submitted via **psub** on the remote cluster. 

Step one in this phase is to look for all **.batchedandchummed** files to get a unique
list of **psub.file** **PSUB** files.  These **PSUB** files should be prefixed with the remote
cluster **<panfish.config::[QUEUE].basedir>** and passed to standard in of 
**<panfish.config::[QUEUE].psub>** command.  The output of this command will generate a new
**MYQSUB** file path for each **QSUB** job file.  This path should be appended to the **.batchedandchummed**
file with this key:

    psub.file=(MYQSUB)

and the **.batchedandchummed** files should have their suffixes switched to **.submitted**


Going from .submitted to .running to .done or .failed
---------------------------------

In this phase the jobs are on the remote cluster and just need to get their status.

In this phase look for all **.submitted** and **.running** files and extract all
the **psub.file** file paths to get a unique list.  Invoke **<panfish.config::[QUEUE].pstat>**
script passing these file paths to standard in.  The output will have status
for each **psub.file**  Based on the status adjust the suffix
for the **.job** files.


Job template Files and Directory
================================

Each remote cluster has a set of directives and configuration options
that must be set.  To handle this mismatch there should be a template job
file for each **QUEUE** in the **<panfish.config::job.template.dir>** which
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

psub
====

This program writes the command given to it to a file with a unique name to the
directory monitored by **psub_mitter** daemon.  The directory is set by **<panfish.config::[QUEUE].psub.dir>>**

These job files known as **psub job files** will have names in this format:
  
    (command file).job

Inside the file is this content:

    current.working.dir=(CURRENT WORKING DIR)
    command.to.run=(COMMAND AND ARGUMENTS)

**psub** sets the **(CURRENT WORKING DIR)** to the directory **psub** was
invoked from.  The **(COMMAND AND ARGUMENTS)** come either from standard in or
from the command line arguments.  If the first argument passed to **psub** is **-**
then **psub** should read from standard in and consider each line a new job file. 

Output should be as follows:

     $ psub (command file)
     (command file).job
     $

For invocation with **-** flag read from standard in and output as follows:

     $ echo -e "(command1)\\n(command2)" | psub -
     (command1).job
     (command2).job
     $

If **(command).job** already exists in the **<panfish.config::[QUEUE].psub.dir>>**
consider this an error and exit with non zero exit code. 

In batch mode first command to fail should cause whole command to fail.



pstat
=====





psub_mitter
===========



 


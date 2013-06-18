
Panfish Functional Specification
================================

By Christopher Churas


Overview
========

Panfish is a set of applications that enable Grid Engine serial jobs to be run on
remote clusters.  

This specification will discuss Panfish from the user perspective and technical implementation
details will be left for another document.  


THIS SPECIFICATION MAY CONTAIN ERRORS AND OMISSIONS.  YOU HAVE BEEN WARNED.


Motivation
==========

Time and time again the following pattern has occurred that involves distributing
work to multiple clusters.  These clusters usually offer only limited access and have
wildly different configurations.  What ends up happening is custom code is written to
send and retreive jobs on these clusters.  

Panfish is attempt to generalize this code for a specific type of job so its easier to
integrate these heterogeneous compute resources.

Scenarios
=========

Below is the main driving scenario behind this software.

**Scenario 1:  CAMERA**
The CAMERA project is a Metagenomic Science Gateway with a workflow system 
that allows users to run compute intensive processing on Metagenomic data owned 
by CAMERA as well as data uploaded by the users.  The most used Workflows 
are the Blast Workflows which align user uploaded sequence data against large 
sequence databases maintained by CAMERA.  To meet the processing needs CAMERA
operates and maintains a compute cluster of about three teraflops size.  
Initially this cluster was able to meet the needs of the community, but as the 
datasets grew and sequencing technology improved this is no longer the case.  
For various reasons, CAMERA was not in the position to increase the in house 
cluster.  Instead CAMERA was able to get allocations on several external 
compute clusters (Gordon, Codonis, and Trestles).  These clusters offered a 
small persistent storage of 5 terabytes and allocations of around one million 
hours of compute time on each cluster.

Caught in a desparate situation to quickly meet end user compute demands CAMERA
turned to Panfish.  Panfish allows certain types of jobs submitted to Grid Engine
to be run on remote clusters.  The remote clusters can run Grid Engine or OpenPBS aka
Torque.  Since CAMERA currently submits jobs to the in house compute cluster using 
Grid Engine, Panfish looked to be a good fit.

The Blast Workflows use Grid Engine to run thousands of jobs coded in small shell
scripts.  These jobs are submitted with Grid Engine's **qsub** call and monitored
for completion by **qstat**.  

Once initial configuration of Panfish to remote clusters was complete, CAMERA 
developers modified the Blast Workflows swapping the **qsub** call to submit jobs 
with the Panfish version **cast**  In addition, the shell scripts were adjusted
to conform to Panfish specifications.  Finally the Blast Workflows were augmented
with a call to the Panfish command **land** to retreive data after job completion
as determined with standard Grid Engine **qstat** call.  

**Scenario 2:  Beauford**
Beauford is a bioinformatics developer in a small lab.  Catching a glimpse of Beauford
would not lend one to think of him in the software field.  His six foot four
frame complete hands like gorillas, and a beard that would put the Brawny man to shame
leads one to believe his chosen profession to be one serious physical activity.  
The picnic table colored flannels he religiously wears further biases one beliefs.  
However unexpected the career choice, here is Beauford and he is tasked with 
developing and running the processing pipelines for his lab.  Students, 
Post-Docs, and the PI visit him requesting help processing data.  Appearance aside,
Beauford is a most capable software developer and has in his arsenal a knowledge of
unix based systems, and Grid Engine.  To help with the processing needed by the lab
Beauford has a small 8 node compute cluster which he meticulously maintains.  The 
cluster is running Centos 6 and Grid Engine to run the jobs for the lab.  

On an unusually quiet Tuesday, his PI, Dr. Howard McBain, stops by.  Dr. McBain a
man of booming voice and fiery eyes, but at the same time somehow equipped with a 
most compassionate demeanor.  Dr. McBain tells Beauford that he needs an alignment 
run on a truly massive dataset.  A dataset that would take months to run on the 
little cluster.  Dr. McBain already aware of the limitations tells Beauford that he 
has aquired an allocation on an XSEDE super computer and that some of the work can 
be run there.  Beauford stares back at Dr. McBain in silence pondering his options.  
Beauford knows he could just take his scripts and programs, figure out the XSEDE 
cluster, and make adjustments to run the jobs there copying the data back upon 
completion.  But Beauford remembers seeing a link on CAMERA about Panfish, a 
small tool that lets Grid Engine jobs run on remote clusters.  He tells Dr. McBain 
he will start at once on the work and update him on progress. 

Beauford, downloads Panfish and installs it on the cluster.  Panfish is a simple Perl
application with no dependencies and installation is a cinch.  Beauford follows the
setup documentation, by first setting up ssh keys to the XSEDE cluster and verifying
nodes that will be submitting jobs can connect to that cluster.  Once that is verified
Beauford copies up the **psub** script and sets up a cron to run **psub_submitter**
once a minute.  Beauford then runs a test job through **psub** and verifies it works
on XSEDE.  After that Beauford adjusts the Panfish configuration file and template file
for the cluster he will be running on.  These configuration files just need information on
the destination host and paths to run on the remote host as well as location of **psub**.
Once that is complete, he sets up shadow queues on his local Grid Engine, one for his local
cluster and one for the XSEDE cluster.  He then submits using **cast** a test job which he
monitors via **qstat**  Once the job completes he invokes **land** and verifies he has all
the data.  Seeing things working satisfactorily, he modifies his old code base prefixing
all absolute paths with Panfish environment variables.  He then rsyncs static data that
will be needed on those jobs to the remote cluster.  His final operation is to submit a small
subset of data to verify the jobs work.  If they do he will do the big submission.   

Non Goals
=========

This version will **NOT** support the following features

* Support to submit binary jobs directly.  All jobs must be invoked from within shell scripts
  and these shell scripts must be able have their paths prefixed with Panfish environment variables
  so they can locate data on remote clusters.

* Transfer of data back to local after each job completes.  The only way to pull data back is via
  direct rsync or by invoking **land**

* Data pulled back from multiple clusters must not conflict otherwise unknown results will be returned.
  The **land** command will pull back from the remote clusters one cluster at a time and if different
  data under the same file names exist on multiple clusters unknown results will be downloaded.

* Auto scaling of the number of jobs to be run on the remote clusters.  In this implementation the
  admin of the local Grid Engine will pick a number of jobs to allow to go to a remote cluster and
  that will be what can be run.  

* Each job is assumed to require one core and will be batched with other single core jobs to meet the
  number of cores on a given node.  

* If a job on a remote node fails, there will be no restart.  In this version wait until all jobs complete,
  **land** the results and resubmit if necessary.  

* Panfish will be built to support Sun Grid Engine 6.1 and 6.2 on the local cluster.  
  Other versions are not supported.

* Panfish will only support SGE 6.1/6.2 and OpenPBS/Torque on the remote clusters.

* **Cast** will NOT support all argument options of **qsub** only the subset listed below.

Panfish Initialization Flowchart
================================


    ------------------------------
   |                              |
   | User installs panfish        |
   | $ perl Makefile.pl           |
   | $ make;make test             |
   | $ make install               |
   |                              |
    ------------------------------
                  ||
                 _||_
                \    /
                 \  /
                  \/ 
    ------------------------------
   |                              |
   |  User runs panfish_setup     |
   |  Answers questions and sets  |
   |  up ssh keys to all hosts.   |
   |                              |
    ------------------------------            
                  ||
                 _||_
                \    /
                 \  /
                  \/
    ------------------------------
   |                              |
   | User runs panfish_test to    |
   | verify correct installation  |
   |                              |
    ------------------------------



Panfish User Flowchart
======================


     ------------------------------
    |                              |
    | User sets up job for Panfish |
    |                              |
     ------------------------------
                  ||
                 _||_
                \    /
                 \  /
                  \/
     ------------------------------
    |                              |
    | User invokes **chum** on dir |
    | to transfer data to remote   |
    | clusters                     |
    |                              |
     ------------------------------
                  ||
                 _||_
                \    /
                 \  /
                  \/
     ------------------------------
    |                              |
    | User invokes **cast** on job |
    | which submits shadow job and |
    | returns Grid Engine job id   | 
    |                              |
     ------------------------------
                  ||
                 _||_
                \    /
                 \  /
                  \/
     ------------------------------
    |                              |
    | User calls **qstat** on id   |
    | and waits for job completion |
    |                              |
     ------------------------------
                  ||
                 _||_
                \    /
                 \  /
                  \/
     ------------------------------
    |                              |
    | Upon job completion user     |
    | calls **land** to get result |
    |                              |
     ------------------------------

Program by Program Specification
================================

Panfish consists of several command line programs that are invoked by the user.  
All command line programs will have a help page available with -h|-help flag 
and a more detailed help page with -man flag.  In addition invoking man on any 
of the commands should kick out the same documentaion as the -man flag.  


Panfish_setup
-------------

Command line program invoked by the user.  The purpose of this program is to assist the user in
setting up Panfish to work with remote clusters.  

     panfish_setup (options)

**(options)**

* **--addcluster <cluster name | [ file ] >**

This parameter lets a caller add a cluster.  The user can either pass in a name which will
cause the program to run in an interactive mode asking lots of questions necessary to enable
the cluster, OR the user can pass in a file with the configuration information.  
Part of this process uploads binaries and sets up directories on that remote cluster.

* **--updatecluster <cluster name | [ file ] >**

Updates an existing cluster.


* **--removecluster <cluster name>**

Removes the cluster.

* **--disablecluster <cluster name>**

Disables the cluster.

* **--listcluster (optional name)**

Lists the current clusters and brief information if (optional name) is omitted
otherwise in depth information on specified cluster is output.

Chum
----

Command line program invoked by the user to upload directory to remote clusters that is needed
by the job submitted by the **cast** command below.  

Command Line:

    chum (options)

Uploads a directory to remote cluster specified in options 
or to all clusters listed in the configuration if this option is omitted.

**(options)**

**--path**   **REQUIRED** Directory to upload.

**--cluster**     Comma delimited list of clusters to upload to.  If this is omitted
                  all clusters in configuration file will be used.

* **--retry**     Tries to upload multiple times before failing. Default is 3.

* **--timeout**   Timeout for retry in seconds.  Default is 30 seconds.

* **--dry-run**   Don't do the transfer just say what will be pushed.


Output should look like this:
Examining YYY
Found XX bytes in UU files

Uploading... to YYY ... done.  Rate:  ZZ mb/sec.
Uploading... to YYY ... done.  Rate:  ZZ mb/sec.

With zero exit code upon success or an helpful message on failure


Cast
----

Command line program invoked by the user.  The purpose of this command line program is to submit
a job to Panfish.  It is designed to be a drop in replacement for **qsub** by that regard arguments
that work with **qsub** should work with **cast**.  As noted in the **NON** goals, not all arguments
will be supported cause in some cases those arguments just don't make sense.  In the initial
version these arguments will be supported:

* **-t**  Lets caller specify the submission of an array job.

* **-e**  Lets caller specify standard error stream.  

* **-o**  Lets caller specify standard output stream.

* **-q**  Lets caller specify queues.  These queues should be the **shadow** queues configured for
          Panfish.

* **-N**  Sets job name same as **qsub**.

The above options should also be definable as directives within the script to be submitted using the
format #$PANFISH (flag) convention similar to the one used by Grid Engine. 

The **Cast** program will first upload any data to the remote cluster and then submit the job to
the local Grid Engine.  The output of **Cast** upon success will be the same output from **qsub**
complete with a job id that the user can use to monitor.  

Example invocation:

$ cast -t 1-2 -q gordon_shadow.q,local_shadow.q -e /foo/test/f1/o/\$TASK_ID.err -o /foo/test/f1/o/\$TASK_ID.out /foo/test/f1/testjob.sh
Your job-array 523.1-2:1 ("line") has been submitted

The above will have a 0 exit code upon success or non zero upon failure.  The user can
track his job by running qstat and looking for jobs with id of **523**

An example of cast invocation without an array job:

$ cast -q gordon_shadow.q,local_shadow.q -e /foo/test/f1/o/\$TASK_ID.err -o /foo/test/f1/o/\$TASK_ID.out /foo/test/f1/testjob.sh
Your job 524 ("line") has been submitted


Land
----

Command line program invoked by the user to retreive completed job data on remote clusters.  
This program has the following command line:

    land (options)

**(options)**


* **--path** **REQUIRED** Path to the directory on the local filesystem that
                  should be downloaded from the remote clusters.

* **--cluster**   Comma delimited list of clusters to upload to.  If this is omitted
                  all clusters in configuration file will be used.

* **--retry**     Tries to download multiple times before failing. Default is 3.

* **--timeout**   Timeout for retry in seconds.  Default is 30 seconds.

* **--dry-run**   Don't do the transfer just say what will be pulled.


Upon success zero exit code will be output.

Text output from transfers will be in this format:

Downloading... XX bytes from YYY...Complete Rate:  ZZ mb/sec.
Downloading... XX bytes from YYY...Complete Rate:  ZZ mb/sec.

Where XX is size of data to retreive.  YYY is the cluster data is pulled
from and ZZ is the transfer rate calculated by taking XX bytes divided
by the time to transfer.

If there is an error the message with be prefixed with **ERROR** in a separate
line along with the issue seen and the application will exit with a non-zero 
exit code.

Example of invocation successful:

$ land /foo/blah
Downloading...XX bytes from gordon_shadow...Complete.  Rate: 5.2 mb/sec.
Downloading...XX bytes from foo_shadow...Complete.  Rate: 1.4 mb/sec.
$

Example of failed invocation:
$ land /foo/blah
Downloading...XXX bytes from gordon_shadow...Error
ERROR:  Unable to download from gordon_shadow
$

Example of invalid path invocation:
$ land /foo/blah
ERROR: /foo/blah does not exist on gordon_shadow
$


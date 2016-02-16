package Panfish;

use 5.008008;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Panfish ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
	
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '0.2';


# Preloaded methods go here.

1;
__END__

=head1 NAME

Panfish - A multicluster submission system 

=head1 SYNOPSIS

panfishchum  --path /home/foo --cluster foo_shadow.q,bar_shadow.q

panfishcast -q foo_shadow.q,bar_shadow.q myjob.sh

panfishland --path /home/foo --cluster foo_shadow.q,bar_shadow.q

panfish --cron


=head1 DESCRIPTION

Panfish enables jobs built for Sun Grid Engine/Open Grid Scheduler to 
run on multiple clusters in parallel utilizing tools similar to those
used to submit jobs to Sun Grid Engine/Open Grid Scheduler.  


This document is broken into several parts:

=over

=item B<SETUP>

Describes on how to configure B<Panfish>

=item B<HOW IT WORKS>

Describes how B<Panfish> works

=item B<CREATING A JOB>

Describes how to create a job runnable in B<Panfish>

=item B<CUSTOM TEMPLATE>

Describes structure of templates

=item B<EXAMPLE panfish.config file>

Contains an example F<panfish.config>

=item B<EXAMPLE SGE template file>

Example template for SGE

=item B<EXAMPLE Slurm (stampede) template file>

Example template for Slurm

=item B<EXAMPLE PBS (gordon) template file>

Example template for PBS

=back

=head1 SETUP

Setup of B<Panfish> involves several steps as denoted below.  

=over

=item 1) Creation of shadow queues on Open Grid Scheduler

=item 2) Enabling ssh/rsync access to remote clusters

=item 3) Creation of configuration file

=item 4) Setup of Panfish database

=item 5) Setup of Panfish on remote clusters

=item 6) Setup of Panfish cron on local and remote clusters

Z<>

=item B<1) Creation of shadow queues on Open Grid Scheduler>

B<Panfish> relies on Open Grid Scheduler to decide where jobs should 
be run.  This is done through "shadow" queues that B<panfishcast> 
submits "shadow" jobs to.  These "shadow" jobs merely provide handles 
to the real jobs run on various clusters.  

A "shadow" queue should be created for every cluster that jobs will be 
run on, including one for the local cluster.  The number of I<slots> 
should correspond to number of jobs that is desired to be run on the 
cluster. 

B<NOTE:> I<slots> on Open Grid Scheduler sets number of jobs per node.

A queue can be created via the B<queue -aq> command.  Details of queue
creation are beyond the scope of this document.  Please refer to 
documentation on L<http://gridscheduler.sourceforge.net/>

B<NOTE:> A good convention is to name these queues with a B<_shadow.q> 
suffix.  

=item B<2) Enabling ssh/rsync access to remote clusters>

B<Panfish> relies on ssh/rsync for interacting with remote clusters.  
ssh/rsync is invoked by the following commands: 
B<panfish, panfishchum, panfishland, panfishsetup>

Basically one should be able to ssh <remote host> to all clusters
that will be utilized by B<Panfish>  It is suggested to employ
some sort of passwordless authentication system to avoid repeated 
password prompts.  

How to enable this is well documented and the approaches described
have various security implications:

L<http://linuxconfig.org/passwordless-ssh>
L<http://www.tecmint.com/ssh-passwordless-login-using-ssh-keygen-in-5-easy-steps/>
L<http://www.phcomp.co.uk/Tutorials/Unix-And-Linux/ssh-passwordless-login.html>


=item B<3) Creation of configuration file>

B<Panfish> requires a configuration file.  An example configuration
file can be found in B<Panfish> source tree named F<example.panfish.config>.
Also example template files can be found under B<templates/> directory
in B<Panfish> source tree.

Configuration files found in the following paths are loaded in this 
order:

 1) /etc/panfish.config
 2) <install bin directory>/../etc/panfish.config
 3) <install bin directory>/panfish.config
 4) $HOME/.panfish.config
 5) Path set in environment variable $PANFISH_CONFIG


B<NOTE:> In case of duplicate parameters, the value from last loaded configuration 
file takes precedence.

The configuration file has two parts, one part consists of
global parameters (this.cluster and cluster.list) and the second
part consists of cluster specific parameters.  The cluster
specific parameters are prefixed with the cluster's "shadow" queue
name

B<NOTE:> I<<shadow_queue>> should be replaced with the B<"shadow queue"> name
configured for the remote or local cluster (ie: foo_shadow.q)

The format of the parameters is:

C<key = value>

=over 4

=item B<this.cluster>

Global parameter that defines the shadow queue for this cluster.
The value set here should match the name of the shadow queue setup
on the local Open Grid Engine installation.  ie foo_shadow.q

=item B<cluster.list>

Global parameter that contains comma delimited list of shadow queues
that correspond to clusters is allowed to submit jobs to.  The local
cluster needs to be specified in this list as well.

=item I<<shadow_queue>>.B<host>

Host of remote cluster to submit jobs on and to copy data to/from.
This should be of the form (user)@(host)
Ex:  bob@gordon.sdsc.edu

=item I<<shadow_queue>>.B<engine>

Batch processing system used by cluster.  SGE, PBS, and SLURM are 
currently supported.
NOTE:  Only SGE is supported for the local cluster.

=item I<<shadow_queue>>.B<basedir>

Any jobs on this cluster will have PANFISH_BASEDIR environment
variable set to this path.  On local cluster its usually
left empty, but on remote clusters it needs to be set

=item I<<shadow_queue>>.B<database.dir>

Directory where database of jobs is stored

=item I<<shadow_queue>>.B<job.template.dir>

Contains job template files for the various clusters
Each template file has the same name as the shadow queue

See B<templates/> folder in Panfish source tree for examples.

=item I<<shadow_queue>>.B<submit>

Full path to qsub or sbatch

=item I<<shadow_queue>>.B<stat>

Full path to qstat or squeue

=item I<<shadow_queue>>.B<bin.dir>

Bin directory containing panfish scripts/binaries

=item I<<shadow_queue>>.B<max.num.running.jobs>

Maximum number of jobs allowed to run on this cluster

=item I<<shadow_queue>>.B<submit.sleep>

Number of seconds to sleep between submissions of jobs

=item I<<shadow_queue>>.B<scratch>

Scratch or temporary directory for jobs on this cluster.  This
path is accessible via PANFISH_SCRATCH environment variable
can execute a command if backticks are employed. 

Example:

`/bin/ls /scratch/$USER/[0-9]* -d`

=item I<<shadow_queue>>.B<jobs.per.node>

Sets number of "same" serials that can be batched on one node.
Usually set to of cores on node

=item I<<shadow_queue>>.B<job.batcher.override.timeout>

Number of seconds to wait before sending out a batch job with
an insufficient number of jobs batched together

=item I<<shadow_queue>>.B<line.sleep.time>

Number of seconds the panfishline shadow job should sleep before
querying the database to see if the real job has changed state

=item I<<shadow_queue>>.B<line.stdout.path>

Directory to write the standard out/error stream for the shadow job.
This output needs to go somewhere and is not relevant to the user so 
we have it written to a special side directory.  The output is merged 
into a single file to reduce disk IO.  Setting to /dev/null will 
disable writing of any output which should be the default setting 
unless low level debugging is needed.

=item I<<shadow_queue>>.B<line.log.verbosity>

Level of logging verbosity for panfishline
0 = outputs only error,warning, and fatal messages.
1 = adds info messages.
2 = adds debug messages. 

=item I<<shadow_queue>>.B<land.max.retries>

Number of retries panfishland command should make when attempting a
retreival of data.

=item I<<shadow_queue>>.B<land.wait>

Number of seconds panfishland command should wait between transfer
retries.

=item I<<shadow_queue>>.B<rsync.timeout>

Sets the rsync IO timeout in seconds. (--timeout)

=item I<<shadow_queue>>.B<rsync.contimeout>

Sets the rsync connection timeout in seconds. (--contimeout)

=item I<<shadow_queue>>.B<panfish.log.verbosity>

Level of verbosity for panfish
0 = outputs only error,warning, and fatal messages.
1 = adds info messages.
2 = adds debug messages. 


=item I<<shadow_queue>>.B<panfishsubmit.log.verbosity>

Level of logging verbosity for panfishsubmit
0 = outputs only error,warning, and fatal messages.
1 = adds info messages.
2 = adds debug messages.

=item I<<shadow_queue>>.B<io.retry.count>

Number of times to retry an IO operation such as ssh or copy

=item I<<shadow_queue>>.B<io.retry.sleep>

Seconds to wait before a retry of an IO operation

=item I<<shadow_queue>>.B<io.timeout>

Seconds to set for timeout of IO operation

=item I<<shadow_queue>>.B<io.connect.timeout>

Seconds to set for connection timeout of IO operation

=item I<<shadow_queue>>.B<job.account>

Account, if any, that should be set when submitting a job
This value is used to replace the @PANFISH_ACCOUNT@ token
that can optionally be set in the template file

=item I<<shadow_queue>>.B<job.walltime>

Walltime to set for job.  Format is: HH:MM:SS ie 12:00:00 means
12 hours

=back

=item B<4) Setup of Panfish database>

Once the configuration file from previous step is correctly configured setting
up the database can be done via this invocation:

C<panfishsetup --setupdball>

The above command creates a file system jobs database in the path set
via I<<shadow_queue>>.B<database.dir> parameter for the cluster where
I<<shadow_queue>> matches the "shadow" queue set in B<this.cluster> 
parameter 

See C<man panfishsetup> for more information.

=item B<5) Setup of Panfish on remote clusters>

B<Panfish> requires scripts and other files to be persisted to the
remote clusters.  This can be accomplished via this command:

C<panfishsetup --syncall>

The above command uploads needed B<Panfish> scripts and a copy of the
configuration file to the remote cluster.  

See C<man panfishsetup> for more information.

=item B<6) Setup of Panfish cron on local and remote clusters>

B<panfish> command needs to be run on the local cluster periodically to submit
jobs to local and remote clusters and to update status of completed jobs to the
database.  One option is to manually invoke B<panfish> --cron periodically on the
local cluster and on the remote clusters.  Another option is to leverage
cron.

Here is a cron for the local cluster that runs once every 5 minutes:

C<*/5 * * * * . /opt/ge2011.11/default/common/settings.sh;/usr/local/bin/panfish --cron E<gt>E<gt> /tmp/panfish.log 2E<gt>&1>

On remote clusters a similar cron can be added:

C<*/10 * * * * panfish --cron E<gt>E<gt> <path to a log fileE<gt> 2E<gt>&1>

=back

=head1 HOW IT WORKS

B<Panfish> takes a script based commandline job and runs that job on a local or remote
cluster.  In addition, B<Panfish> also assists in the serialization and deserialization
of data on those clusters.

Panfish is not a batch processing scheduler on its own, it can be thought of as
a wrapper on top of Open Grid Scheduler that handles the logistics of ferrying jobs
to/from remote clusters.

The benefit of the wrapper is most jobs that work in Open Grid Engine 
could in theory be run through B<Panfish> with only minimal changes.
B<Panfish> also benefits from not having to reinvent the wheel when 
deciding what job to run, that task is left to Open Grid Scheduler.

In a normal scenario using Open Grid Scheduler the user does the following:

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

With B<Panfish> the user does the following:

    User ----> [invokes] ----> panfishchum
     ||                         ||
     ||                         \/
     ||  <--------------- [transfers data]
     \/
    User ----> [invokes] ----> panfishcast (instead of qsub)
     ||                         ||
     ||                         \/
     ||  <--------- [returns job id to caller]
     \/
    User ----> [invokes] ----> qstat
     ||                         ||
     ||                         \/
     ||  <------------- [returns job status]
     \/
    User ----> [invokes] ----> panfishland
     ||                         ||
     ||                         \/
    Done <-------- [data retreived from clusters]

The user first uploads data for the job by calling B<panfishchum>.  The 
user then calls B<panfishcast> which submits a "shadow" job to the local 
queuing system.  As part of the submission, is a list of valid "shadow" 
queues which correspond to remote clusters the job can run under.  The 
user is given the id of the shadow job by the B<panfishcast> command.  
The user then simply waits for those jobs to complete through calls to 
B<qstat>.

Open Grid Scheduler then schedules the "shadow" job, B<panfishline>, to 
an available "shadow" queue.  Once the "shadow" job starts it informs 
B<Panfish> that a job can be run on a cluster as defined by the queue 
the "shadow" job was run under.  B<Panfish> runs the job on the remote 
cluster, and informs the "shadow" job when the real job completes.

Upon detecting all jobs have completed, the user invokes B<panfishland> 
to retreive data from all the clusters.

Before any job can run on the remote clusters, the job and its 
corresponding data need to reside there.  The job script is transferred 
by B<Panfish> daemon, but something needs to upload the data and that 
responsibility is left to the user to invoke B<panfishchum> and 
B<panfishland>.

B<Panfish> requires all file paths to be prefixed with the environment
variable B<PANFISH_BASEDIR> which will be set appropriately on each
cluster, (or not set at all if the job ends up locally.)

For example say we had this job script:

 #!/bin/bash
  
 echo "Today is: `date`" > /home/foo/j1/thedate.txt

If the above was run on the remote cluster it may fail cause
B</home/foo/j1> may not exist on that cluster.  To deal with this, the
job needs to prefix all paths with B<PANFISH_BASEDIR>  as seen here:

 !/bin/bash

 echo "Today is: `date`" > $PANFISH_BASEDIR/home/foo/j1/thedate.txt

Now B<Panfish> can run the job under an alternate path.
 

=head1 CREATING A JOB

Here is an example serial job script that can be run via B<Panfish>:

 #!/bin/bash
 
 echo "cwd: `pwd`"
 echo "output for stderr" 1>&2
 echo "JOB_ID = $JOB_ID"
 echo "SGE_TASK_ID = $SGE_TASK_ID"
 echo "SGE_TASK_STEPSIZE = $SGE_TASK_STEPSIZE"
 echo "SGE_TASK_LAST = $SGE_TASK_LAST"
 echo "PANFISH_BASEDIR = $PANFISH_BASEDIR"
 echo "PANFISH_SCRATCH = $PANFISH_SCRATCH"
 echo "sleeping 1" 
 sleep 1

 exit 0

On a shared file system visible to compute nodes on cluster create a
directory named B<foo> and put the above script in a file named F<myjob.sh>

change to B<foo> directory and make F<myjob.sh> executable by running:
 
B<chmod a+x myjob.sh>

Test running script directly by invoking:

B<./myjob.sh>

Output like the following should be seen:

 cwd: <path you created foo dir>/foo
 output for stderr
 JOB_ID = 
 SGE_TASK_ID = 
 SGE_TASK_STEPSIZE = 
 SGE_TASK_LAST = 
 PANFISH_BASEDIR = 
 PANFISH_SCRATCH = 
 sleeping 1

To run this job on local cluster try the following

B<panfishcast -q foo_shadow.q -e `pwd`/\$JOB_ID\.\$TASK_ID.err -o `pwd`/\$JOB_ID\.\$TASK_ID.out `pwd`/myjob.sh>

Which should output something like this:

 Your job 29401 ("panfishline") has been submitted

Invoking B<qstat> will reveal this which will go away when the job is completed:

 $ qstat

 job-ID  prior   name       user         state submit/start at     queue                          slots ja-task-ID 

 ----------------------------------------------------------------------------
 29401 0.55500 panfishlin churas       r     06/05/2015 14:07:10 foo_shadow.q@foo-3   1        





=head1 EXAMPLE panfish.config file 

Below is an example F<panfish.config> file.  The configuration below
puts the panfish job database and template directory under B</tmp/panfish>
directory.  

 this.cluster=foo_shadow.q
 cluster.list=foo_shadow.q,gordon_shadow.q,stampede_shadow.q

 #
 # config for foo_shadow local SGE cluster
 # 
 foo_shadow.q.host=
 foo_shadow.q.engine=SGE
 foo_shadow.basedir=
 foo_shadow.q.database.dir=/tmp/panfish/jobs
 foo_shadow.q.job.template.dir=/tmp/panfish/templates
 foo_shadow.q.submit=/opt/gridengine/bin/linux-x64/qsub
 foo_shadow.q.stat=/opt/gridengine/bin/linux-x64/qstat
 foo_shadow.q.bin.dir=/tmp/panfish/bin
 foo_shadow.q.max.num.running.jobs=1
 foo_shadow.q.submit.sleep=1
 foo_shadow.q.scratch=/tmp
 foo_shadow.q.jobs.per.node=1
 foo_shadow.q.job.batcher.override.timeout=10
 foo_shadow.q.line.sleep.time=180
 foo_shadow.q.line.stdout.path=/dev/null
 foo_shadow.q.line.log.verbosity=1
 foo_shadow.q.land.max.retries=10
 foo_shadow.q.land.wait=100
 foo_shadow.q.land.rsync.timeout=180
 foo_shadow.q.land.rsync.contimeout=100
 foo_shadow.q.panfish.log.verbosity=1
 foo_shadow.q.panfishsubmit.log.verbosity=1
 foo_shadow.q.io.retry.count=2
 foo_shadow.q.io.retry.sleep=5
 foo_shadow.q.io.timeout=30
 foo_shadow.q.io.connect.timeout=30
 foo_shadow.q.job.account=
 foo_shadow.q.job.walltime=12:00:00

 #
 # Example config for Gordon XSEDE cluster
 #
 gordon_shadow.q.host=<YOUR USERNAME>@gordon.sdsc.edu
 gordon_shadow.q.engine=PBS
 gordon_shadow.q.basedir=/oasis/scratch/$USER/temp_project
 gordon_shadow.q.submit=/opt/torque/bin/qsub
 gordon_shadow.q.stat=/opt/torque/bin/qstat
 gordon_shadow.q.bin.dir=/home/$USER/panfish/bin
 gordon_shadow.q.database.dir=/home/$USER/panfish/jobs
 gordon_shadow.q.max.num.running.jobs=20
 gordon_shadow.q.submit.sleep=5
 gordon_shadow.q.scratch=`/bin/ls /scratch/$USER/[0-9]* -d`
 gordon_shadow.q.jobs.per.node=16
 gordon_shadow.q.job.batcher.override.timeout=1800
 gordon_shadow.q.line.sleep.time=60
 gordon_shadow.q.land.max.retries=10
 gordon_shadow.q.land.wait=100
 gordon_shadow.q.land.rsync.timeout=180
 gordon_shadow.q.land.rsync.contimeout=100
 gordon_shadow.q.panfish.log.verbosity=1
 gordon_shadow.q.panfishsubmit.log.verbosity=1
 gordon_shadow.q.panfish.sleep=60
 gordon_shadow.q.io.retry.count=2
 gordon_shadow.q.io.retry.sleep=5
 gordon_shadow.q.io.timeout=30
 gordon_shadow.q.io.connect.timeout=30
 gordon_shadow.q.job.account=<YOUR ACCOUNT>
 gordon_shadow.q.job.walltime=12:00:00

 #
 # Example config for Stampede XSEDE cluster
 #
 stampede_shadow.q.host=<YOUR USERNAME>@stampede.tacc.xsede.org
 stampede_shadow.q.engine=SLURM
 stampede_shadow.q.basedir=<YOUR $WORK DIR>/panfish
 stampede_shadow.q.database.dir=<YOUR $HOME DIR>/panfish/jobs
 stampede_shadow.q.submit=/usr/bin/sbatch
 stampede_shadow.q.stat=/usr/bin/squeue -u tg802810
 stampede_shadow.q.bin.dir=<YOUR $HOME DIR>/panfish/bin
 stampede_shadow.q.max.num.running.jobs=50
 stampede_shadow.q.submit.sleep=1
 stampede_shadow.q.scratch=/tmp
 stampede_shadow.q.jobs.per.node=16
 stampede_shadow.q.job.batcher.override.timeout=1800
 stampede_shadow.q.panfish.log.verbosity=2
 stampede_shadow.q.panfishsubmit.log.verbosity=1
 stampede_shadow.q.panfish.sleep=60
 stampede_shadow.q.io.retry.count=2
 stampede_shadow.q.io.retry.sleep=5
 stampede_shadow.q.io.timeout=30
 stampede_shadow.q.io.connect.timeout=30
 stampede_shadow.q.job.account=<YOUR ACCOUNT>
 stampede_shadow.q.job.walltime=12:00:00

=head1 EXAMPLE SGE template file

This is an example template file for Open Grid Scheduler 
L<http://gridscheduler.sourceforge.net/>

 #!/bin/sh
 #
 # request Bourne shell as shell for job
 #$ -S /bin/sh
 #$ -V
 #$ -wd @PANFISH_JOB_CWD@
 #$ -o @PANFISH_JOB_STDOUT_PATH@
 #$ -e @PANFISH_JOB_STDERR_PATH@
 #$ -N @PANFISH_JOB_NAME@
 #$ -q all.q
 #$ -l h_rt=@PANFISH_WALLTIME@

 echo "SGE Id:  ${JOB_ID}.${SGE_TASK_ID}"

 /usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@

=head1 EXAMPLE Slurm (stampede) template file

This is an example template file for Slurm 
L<http://computing.llnl.gov/linux/slurm/> and
is configured for Stampede L<https://www.tacc.utexas.edu/stampede/>

 #!/bin/sh
 #
 #SBATCH -D @PANFISH_JOB_CWD@
 #SBATCH -A @PANFISH_ACCOUNT@
 #SBATCH -o @PANFISH_JOB_STDOUT_PATH@
 #SBATCH -e @PANFISH_JOB_STDERR_PATH@
 #SBATCH -J @PANFISH_JOB_NAME@
 #SBATCH -p normal
 #SBATCH -t @PANFISH_WALLTIME@
 #SBATCH -n 1
 #SBATCH --export=SLURM_UMASK=0022

 /usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@

=head1 EXAMPLE PBS (gordon) template file

This is an example template file for PBS Portal Batch System
and is configured for Gordon L<https://portal.xsede.org/sdsc-gordon>

 !/bin/sh
 #
 #PBS -q normal
 #PBS -m n
 #PBS -A @PANFISH_ACCOUNT@
 #PBS -W umask=0022
 #PBS -o @PANFISH_JOB_STDOUT_PATH@
 #PBS -e @PANFISH_JOB_STDERR_PATH@
 #PBS -V
 #PBS -l nodes=1:ppn=16,walltime=@PANFISH_WALLTIME@
 #PBS -N @PANFISH_JOB_NAME@
 #PBS -d @PANFISH_JOB_CWD@

 /usr/bin/time -p @PANFISH_RUN_JOB_SCRIPT@ @PANFISH_JOB_FILE@



=head1 SEE ALSO

L<panfishcast(1)>, 
L<panfishchum(1)>,
L<panfishjobrunner(1)>,
L<panfishland(1)>,
L<panfishline(1)>,
L<panfishsetup(1)>,
L<panfishstat(1)>

=head1 AUTHOR

Christopher Churas <churas@ncmir.ucsd.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2013 The Regents of the University of California All Rights Reserved

Permission to copy, modify and distribute any part of this Panfish for educational, research and non-profit purposes, without fee, and without a written agreement is hereby granted, provided that the above copyright notice, this paragraph and the following three paragraphs appear in all copies.

Those desiring to incorporate this Panfish into commercial products or use for commercial purposes should contact the Technology Transfer Office, University of California, San Diego, 9500 Gilman Drive, Mail Code 0910, La Jolla, CA 92093-0910, Ph: (858) 534-5815, FAX: (858) 534-7345, E-MAIL:invent@ucsd.edu.

IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS Panfish, EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

THE Panfish PROVIDED HEREIN IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS. THE UNIVERSITY OF CALIFORNIA MAKES NO REPRESENTATIONS AND EXTENDS NO WARRANTIES OF ANY KIND, EITHER IMPLIED OR EXPRESS, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, OR THAT THE USE OF THE Panfish WILL NOT INFRINGE ANY PATENT, TRADEMARK OR OTHER RIGHTS. 


=cut

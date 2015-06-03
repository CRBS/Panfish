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

=head1 SETUP

Setup of B<Panfish> involves several steps as denoted below.  

=item 1) Creation of shadow queues on Open Grid Scheduler

=item 2) Enabling ssh/rsync access to remote clusters

=item 3) Creation of configuration file

=item 4) Setup of Panfish on remote clusters

=item 5) Setup of Panfish cron on local cluster

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

B<NOTE:> I<slots> on Open Grid Scheduler corresponds to tasks per node.

A queue can be created via the B<queue -aq> command.  Details of queue
creation are beyond the scope of this document.  Please refer to 
documentation on <http://gridscheduler.sourceforge.net/>

B<NOTE:> A good convention is to name these queues with a B<_shadow.q> 
suffix.  

=head1 CONFIGURATION FILE

B<Panfish> requires a configuration file.  Any configuration files
found in the following paths are loaded in this order:

 1) /etc/panfish.config
 2) <install bin directory>/../etc/panfish.config
 3) <install bin directory>/panfish.config
 4) $HOME/.panfish.config
 5) Path set in environment variable $PANFISH_CONFIG


B<NOTE:> In case of duplicate parameters, the value from last loaded configuration 
file takes precedence

The configuration file has two parts, one part consists of
global parameters (this.cluster and cluster.list) and the second
part consists of cluster specific parameters.  The cluster
specific parameters are prefixed with the cluster's shadow queue
name

B<NOTE:> I<<shadow_queue>> should be replaced with the B<"shadow queue"> name
configured for the remote or local cluster (ie: foo_shadow.q)

The format of the parameters is:

key = value

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
See templates/ folder in Panfish source tree for examples

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



=head1 SEE ALSO


=head1 AUTHOR

Christopher Churas <churas@ncmir.ucsd.edu>

=head1 COPYRIGHT AND LICENSE

Copyright 2013 The Regents of the University of California All Rights Reserved

Permission to copy, modify and distribute any part of this Panfish for educational, research and non-profit purposes, without fee, and without a written agreement is hereby granted, provided that the above copyright notice, this paragraph and the following three paragraphs appear in all copies.

Those desiring to incorporate this Panfish into commercial products or use for commercial purposes should contact the Technology Transfer Office, University of California, San Diego, 9500 Gilman Drive, Mail Code 0910, La Jolla, CA 92093-0910, Ph: (858) 534-5815, FAX: (858) 534-7345, E-MAIL:invent@ucsd.edu.

IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS, ARISING OUT OF THE USE OF THIS Panfish, EVEN IF THE UNIVERSITY OF CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

THE Panfish PROVIDED HEREIN IS ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS. THE UNIVERSITY OF CALIFORNIA MAKES NO REPRESENTATIONS AND EXTENDS NO WARRANTIES OF ANY KIND, EITHER IMPLIED OR EXPRESS, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE, OR THAT THE USE OF THE Panfish WILL NOT INFRINGE ANY PATENT, TRADEMARK OR OTHER RIGHTS. 


=cut

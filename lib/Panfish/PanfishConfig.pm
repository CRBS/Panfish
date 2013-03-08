package Panfish::PanfishConfig;

use strict;
use English;
use warnings;

use FindBin qw($Bin);

=head1 SYNOPSIS
   
  Panfish::PanfishConfig -- Represents a Panfish configuration

=head1 DESCRIPTION

 Represents Panfish configuration. 

=head1 METHODS

=head3 new

=cut

sub new {
   my $class = shift;
   my $self = {
     Config               => shift,
     THIS_CLUSTER         => "this.cluster",     
     QSUB_PATH            => "qsub.path",
     CLUSTER_LIST         => "cluster.list",
     LINE_VERBOSITY       => "line.log.verbosity",
     PANFISH_VERBOSITY    => "panfish.log.verbosity",
     PANFISHSUBMIT_VERBOSITY => "panfishsubmit.log.verbosity",
     LINE_SLEEP_TIME      => "line.sleep.time",
     LINE_STDERR_PATH     => "line.stderr.path",
     LINE_STDOUT_PATH     => "line.stdout.path",
     JOB_TEMPLATE_DIR     => "job.template.dir",
     LINE_COMMAND         => "line",
     BASE_DIR             => "basedir",
     HOST                 => "host",
     JOBS_PER_NODE        => "jobs.per.node",
     RUN_JOB_SCRIPT       => "run.job.script",
     BATCHER_OVERRIDE     => "job.batcher.override.timeout",
     PANFISH_SUBMIT       => "panfishsubmit",
     PANFISH_STAT         => "panfishstat",
     DATABASE_DIR         => "database.dir",
     QSUB                 => "qsub",
     QSTAT                => "qstat",
     MAX_NUM_RUNNING_JOBS => "max.num.running.jobs",
     ENGINE               => "engine",
     SCRATCH              => "scratch"
     
   };
   
   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 setConfig

Sets config object

=cut

sub setConfig {
  my $self = shift;
  $self->{Config} = shift;
}


sub _getValueFromConfig {
    my $self = shift;
    my $key = shift; 
    my $cluster = shift;
    if (!defined($self->{Config})){
        return undef;
    }

    if (!defined($cluster)){
      $key = $self->getThisCluster().".".$key;
    }
    elsif ($cluster ne ""){
      $key = $cluster.".".$key;
    }

    return $self->{Config}->getParameterValue($key);
}

=head3 getThisCluster 

Gets the cluster that this config is running on aka the cluster
that is considered local

=cut

sub getThisCluster {
    my $self = shift;
    return $self->_getValueFromConfig($self->{THIS_CLUSTER},"");

}

=head3 getScratchDir 

Gets the scratch directory for the cluster

=cut

sub getScratchDir {
   my $self = shift;
   my $cluster = shift;
   return $self->_getValueFromConfig($self->{SCRATCH},$cluster);
}

=head3 getMaximumNumberOfRunningJobs 

Gets Maximum number of running jobs allowed to be run on this cluster

=cut

sub getMaximumNumberOfRunningJobs {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{MAX_NUM_RUNNING_JOBS},$cluster);
}

=head3 getEngine

Get the scheduler used on the cluster

=cut

sub getEngine {
   my $self = shift;
   my $cluster = shift;
   return $self->_getValueFromConfig($self->{ENGINE},$cluster);
}

=head3 getBaseDir

Gets the base directory for the cluster.

=cut

sub getBaseDir {
   my $self = shift;
   my $cluster = shift;
   
   return $self->_getValueFromConfig($self->{BASE_DIR},$cluster);
}

=head3 getQsub 

Gets path to qsub for cluster

=cut

sub getQsub {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{QSUB},$cluster);
}


=head3 getQstat

Gets path for qstat for cluster

=cut

sub getQstat {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{QSTAT},$cluster);
}



=head3 getDatabaseDir

Gets the directory where panfishsubmit places job files for the
cluster specified.

=cut 

sub getDatabaseDir {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{DATABASE_DIR},$cluster);
}


=head3 getPanfishStat

Gets the path on the remote cluster to panfishstat
binary.  This method expects a cluster as a parameter.

my $psub = $foo->getPanfishStat("gordon_shadow.q");

=cut

sub getPanfishStat {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{PANFISH_STAT},$cluster);
}



=head3 getPanfishSubmit 

Gets the path on the remote cluster to panfishsubmit
binary.  This method expects a cluster as a parameter.

my $psub = $foo->getPanfishSubmit("gordon_shadow.q");

=cut

sub getPanfishSubmit {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{PANFISH_SUBMIT},$cluster);
}




=head3 getLineVerbosity

Defines the logging level the line program should use

=cut

sub getLineVerbosity {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{LINE_VERBOSITY},$cluster);
}

=head3 getPanfishVerbosity

Defines the logging level the panfish daemon should use

=cut

sub getPanfishVerbosity {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{PANFISH_VERBOSITY},$cluster);
}

=head3 getPanfishSubmitVerbosity

Defines logging level panfishsubmit should use

=cut

sub getPanfishSubmitVerbosity {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{PANFISHSUBMIT_VERBOSITY},$cluster);
}

=head3 getJobTemplateDir

Gets the job template directory

=cut

sub getJobTemplateDir {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{JOB_TEMPLATE_DIR},$cluster);
}


=head3 getJobsPerNode 

Given a cluster this method gets the number of jobs that should
be batched up per node

=cut

sub getJobsPerNode {
    my $self = shift;
    my $cluster =shift;
    return $self->_getValueFromConfig($self->{JOBS_PER_NODE},$cluster);
}

=head3 getJobBatcherOverrideTimeout 


=cut

sub getJobBatcherOverrideTimeout {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{BATCHER_OVERRIDE},$cluster);
}

=head3 getCommaDelimitedClusterList

Gets a comma delimited list of clusters from the configuration filtered by
the list of clusters passed in to this method.  If the cluster list passed in
has invalid values then an error is returned otherwise $error below is set to undef.

my ($error,$cList) = $config->getCommaDelimitedClusterList();

or

my ($error,$cList) = $config->getCommaDelimitedClusterList("lion_shadow.q,pokey_shadow.q");

=cut

sub getCommaDelimitedClusterList {
    my $self = shift;
    my $clusterList = shift;

    my ($error,@cArray) = $self->getClusterListAsArray($clusterList);
    
    if (defined($error)){
       return ($error,undef);
    }

    my $cList = "";
    for (my $x = 0; $x < @cArray; $x++){
        if ($cList eq ""){
            $cList = "$cArray[$x]";
        }
        else{
            $cList .= ",$cArray[$x]";
        }
    }
    return (undef,$cList);
}

=head3 getClusterListAsArray

Gets array of clusters from the configuration filtered by
the list of clusters passed in to this method.  If the cluster list passed in
has invalid values then an error is returned otherwise $error below is set to undef.

my ($error,$cArray) = $config->getCommaDelimitedClusterList();

or

my ($error,@cArray) = $config->getCommaDelimitedClusterList("lion_shadow.q,pokey_shadow.q");

=cut

sub getClusterListAsArray {
    my $self = shift;
    my $clusterList = shift;

    my @cArray = split(",",$self->_getValueFromConfig($self->{CLUSTER_LIST},""));

    if (!defined($clusterList)){
        return (undef,@cArray);
    }

    # a cluster list was defined so we need to verify all entries in 
    # that list exist in configuration otherwise we have a problem.
    my %cHash;

    for (my $x = 0 ; $x < @cArray; $x++){
       $cHash{$cArray[$x]} = 1;
    }

    my @cArrayFromParam = split(",",$clusterList);

    my @finalArray;
    
    for (my $x = 0; $x < @cArrayFromParam; $x++){
        if (defined($cHash{$cArrayFromParam[$x]})){
            push(@finalArray,$cArrayFromParam[$x]);
        }
        else {
           return ("$cArrayFromParam[$x] is not a valid cluster",undef);
        }
    }
    return (undef,@finalArray);
}

=head3 getLineCommand

Returns the line program name

=cut

sub getLineCommand {
    my $self = shift; # technically don't need to bother to do this
    return "$Bin/".$self->{LINE_COMMAND};
}

=head3 getLineStandardErrorPath 

Gets the Standard error directory for line command

=cut

sub getLineStandardErrorPath {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{LINE_STDERR_PATH},$cluster);
}


=head3 getLineStandardOutPath 

Gets the Standard out directory for line command

=cut

sub getLineStandardOutPath {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{LINE_STDOUT_PATH},$cluster);
}

=head3 getLineSleepTime

Gets the time in seconds the Line program should
wait between checks on the real job

=cut

sub getLineSleepTime {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{LINE_SLEEP_TIME},$cluster);
}


=head3 getRunJobScript

Gets the run job script for the cluster specified

=cut

sub getRunJobScript {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($self->{RUN_JOB_SCRIPT},$cluster);
}

=head3 getHost 

Gets the host of the local cluster or of the cluster 
passed in.

my $host = $c->getHost("gordon_shadow.q");

or

my $host = $c->getHost();

=cut

sub getHost {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($self->{HOST},$cluster);
}


=head3 getAllSetValues

Returns all the set values in this object

=cut

sub getAllSetValues {
    my $self = shift;

    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getAllSetValues();
}

1;

__END__

=head1 AUTHOR

Panfish::PanfishConfig is written by Christopher Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut


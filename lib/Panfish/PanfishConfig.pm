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
     Config             => shift,
     QSUB_PATH          => "qsub.path",
     CLUSTER_LIST       => "cluster.list",
     LINE_VERBOSITY     => "line.log.verbosity",
     PANFISH_VERBOSITY  => "panfish.log.verbosity",
     LINE_SLEEP_TIME    => "line.sleep.time",
     LINE_STDERR_PATH   => "line.stderr.path",
     LINE_STDOUT_PATH   => "line.stdout.path",
     SUBMIT_DIR         => "submit.dir",
     JOB_TEMPLATE_DIR   => "job.template.dir",
     LINE_COMMAND       => "line",
     BASEDIR            => "basedir",
     HOST               => "host",
     JOBS_PER_NODE      => "jobs.per.node",
     RUN_JOB_SCRIPT     => "run.job.script",
     BATCHER_OVERRIDE   => "job.batcher.override.timeout",
     PANFISH_SUBMIT     => "panfishsubmit",
     PANFISH_STAT       => "panfishstat",
     JOB_DIR            => "job.dir",
     QSUB               => "qsub",
     QSTAT              => "qstat",
     
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
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($key);
}


=head3 getClusterQsub 

Gets path to qsub for cluster

=cut

sub getClusterQsub {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($cluster.".".
                                      $self->{QSUB});
}


=head3 getClusterQstat

Gets path for qstat for cluster

=cut

sub getClusterQstat {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($cluster.".".
                                      $self->{QSTAT});
}



=head3 getClusterJobDir

Gets the directory where panfishsubmit places job files for the
cluster specified.

=cut 

sub getClusterJobDir {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($cluster.".".
                                      $self->{JOB_DIR});
}


=head3 getPanfishStat

Gets the path on the remote cluster to panfishstat
binary.  This method expects a cluster as a parameter.

my $psub = $foo->getPanfishStat("gordon_shadow.q");

=cut

sub getPanfishStat {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($cluster.".".
                                      $self->{PANFISH_STAT});
}



=head3 getPanfishSubmit 

Gets the path on the remote cluster to panfishsubmit
binary.  This method expects a cluster as a parameter.

my $psub = $foo->getPanfishSubmit("gordon_shadow.q");

=cut

sub getPanfishSubmit {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($cluster.".".
                                      $self->{PANFISH_SUBMIT});
}




=head3 getLineVerbosity

Defines the logging level the line program should use

=cut

sub getLineVerbosity {
    my $self = shift;
    return $self->_getValueFromConfig($self->{LINE_VERBOSITY});
}

=head3 getPanfishVerbosity

Defines the logging level the panfish daemon should use

=cut

sub getPanfishVerbosity {
    my $self = shift;
    return $self->_getValueFromConfig($self->{PANFISH_VERBOSITY});
}



=head3 getJobTemplateDir

Gets the job template directory

=cut

sub getJobTemplateDir {
    my $self = shift;
    return $self->_getValueFromConfig($self->{JOB_TEMPLATE_DIR});
}


=head3 getJobsPerNode 

Given a cluster this method gets the number of jobs that should
be batched up per node

=cut

sub getJobsPerNode {
    my $self = shift;
    my $cluster =shift;
    
    return $self->_getValueFromConfig($cluster.".".$self->{JOBS_PER_NODE});
}

=head3 getJobBatcherOverrideTimeout 


=cut

sub getJobBatcherOverrideTimeout {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($cluster.".".$self->{BATCHER_OVERRIDE});
}

=head3 getQsubPath

Returns path to qsub program

my $val = $foo->getQsubPath();

=cut

sub getQsubPath {
    my $self = shift;

    return $self->_getValueFromConfig($self->{QSUB_PATH});
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

    my @cArray = split(",",$self->_getValueFromConfig($self->{CLUSTER_LIST}));

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

    return $self->_getValueFromConfig($self->{LINE_STDERR_PATH});
}


=head3 getLineStandardOutPath 

Gets the Standard out directory for line command

=cut

sub getLineStandardOutPath {
    my $self = shift;

    return $self->_getValueFromConfig($self->{LINE_STDOUT_PATH});
}

=head3 getLineSleepTime

Gets the time in seconds the Line program should
wait between checks on the real job

=cut

sub getLineSleepTime {
    my $self = shift;

    return $self->_getValueFromConfig($self->{LINE_SLEEP_TIME});
}


=head3 getSubmitDir

Gets the Submit directory or the directory where files representing Panfish
jobs are stored

my $c->getSubmitDir

=cut

sub getSubmitDir {
    my $self = shift;

    return $self->_getValueFromConfig($self->{SUBMIT_DIR});
}


=head3 getClusterBaseDir 

Gets the base directory for the cluster specified.

my $rdir = $c->getClusterBaseDir("gordon_shadow.q");

=cut

sub getClusterBaseDir {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($cluster.".".$self->{BASEDIR});
}

=head3 getClusterRunJobScript

Gets the run job script for the cluster specified

=cut

sub getClusterRunJobScript {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($cluster.".".$self->{RUN_JOB_SCRIPT});
}

=head3 getClusterHost 

Gets the host of the cluster specified.

my $host = $c->getClusterHost("gordon_shadow.q");

=cut

sub getClusterHost {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($cluster.".".$self->{HOST});
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


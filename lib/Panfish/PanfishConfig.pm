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
     Config           => shift,
     QSUB_PATH        => "qsub.path",
     CLUSTER_LIST     => "cluster.list",
     LINE_SLEEP_TIME  => "line.sleep.time",
     LINE_STDERR_PATH => "line.stderr.path",
     LINE_STDOUT_PATH => "line.stdout.path",
     SUBMIT_DIR       => "submit.dir",
     JOB_TEMPLATE_DIR => "job.template.dir",
     LINE_COMMAND     => "line",
     BASEDIR          => "basedir",
     HOST             => "host",
     JOBS_PER_NODE    => "jobs.per.node",
     BATCHER_OVERRIDE => "job.batcher.override.timeout"
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

    if (!defined($self->{Config})){
        return ("panfish.config was not set",undef);
    }

    my @cArray = split(",",$self->{Config}->getParameterValue($self->{CLUSTER_LIST}));

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
    my $cnt = 0;
    for (my $x = 0; $x < @cArrayFromParam; $x++){
        if (defined($cHash{$cArrayFromParam[$x]})){
            $finalArray[$cnt++] = $cArray[$x];
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
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{LINE_STDERR_PATH});
}


=head3 getLineStandardOutPath 

Gets the Standard out directory for line command

=cut

sub getLineStandardOutPath {
    my $self = shift;
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{LINE_STDOUT_PATH});
}

=head3 getLineSleepTime

Gets the time in seconds the Line program should
wait between checks on the real job

=cut

sub getLineSleepTime {
    my $self = shift;
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{LINE_SLEEP_TIME});
}


=head3 getSubmitDir

Gets the Submit directory or the directory where files representing Panfish
jobs are stored

my $c->getSubmitDir

=cut

sub getSubmitDir {
    my $self = shift;
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($self->{SUBMIT_DIR});
}


=head3 getClusterBaseDir 

Gets the base directory for the cluster specified.

my $rdir = $c->getClusterBaseDir("gordon_shadow.q");

=cut

sub getClusterBaseDir {
    my $self = shift;
    my $cluster = shift;

    if (!defined($self->{Config})){
        return undef;
    }
    return $self->{Config}->getParameterValue($cluster.".".$self->{BASEDIR});
}

=head3 getClusterHost 

Gets the host of the cluster specified.

my $host = $c->getClusterHost("gordon_shadow.q");

=cut

sub getClusterHost {
    my $self = shift;
    my $cluster = shift;
  
    if (!defined($self->{Config})){
        return undef;
    }

    return $self->{Config}->getParameterValue($cluster.".".$self->{HOST});
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


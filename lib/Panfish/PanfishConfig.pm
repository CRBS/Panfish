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
     NOTIFICATION_LEVEL   => "email.notification.level",
     NOTIFICATION_EMAIL   => "notification.email",
     NOTIFICATION_SUBJECT => "notification.subject", 
     CLUSTER_LIST         => "cluster.list",
     LINE_VERBOSITY       => "line.log.verbosity",
     PANFISH_VERBOSITY    => "panfish.log.verbosity",
     PANFISHSUBMIT_VERBOSITY => "panfishsubmit.log.verbosity",
     LINE_SLEEP_TIME      => "line.sleep.time",
     LINE_STDOUT_PATH     => "line.stdout.path",
     JOB_TEMPLATE_DIR     => "job.template.dir",
     BASE_DIR             => "basedir",
     HOST                 => "host",
     JOBS_PER_NODE        => "jobs.per.node",
     LINE_COMMAND         => "panfishline",
     PANFISH              => "panfish",
     PANFISH_JOB_RUNNER   => "panfishjobrunner",
     PANFISH_SETUP        => "panfishsetup",
     BATCHER_OVERRIDE     => "job.batcher.override.timeout",
     PANFISH_SUBMIT       => "panfishcast",
     PANFISH_STAT         => "panfishstat",
     DATABASE_DIR         => "database.dir",
     SUBMIT               => "submit",
     STAT                 => "stat",
     MAX_NUM_RUNNING_JOBS => "max.num.running.jobs",
     ENGINE               => "engine",
     SCRATCH              => "scratch",
     PANFISH_SLEEP        => "panfish.sleep",  
     BIN_DIR              => "bin.dir",
     IO_RETRY_COUNT       => "io.retry.count",
     IO_RETRY_SLEEP       => "io.retry.sleep",
     IO_TIMEOUT           => "io.timeout",
     IO_CONNECT_TIMEOUT   => "io.connect.timeout",
     ACCOUNT              => "job.account",
     WALLTIME             => "job.walltime",
     COMMANDS_FILE_SUFFIX => ".commands",
     PSUB_FILE_SUFFIX     => ".psub",
     REAL_JOB_FILE_DIR    => "real_jobfile_dir",
     ALIAS_TO             => "alias.to"
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

=head3 updateWithConfig 

Updates object with parameters from configuration passed
in.  Any parameters found in this config will override
previously set configurations.  

=cut
sub updateWithConfig {
  my $self = shift;
  my $config = shift;
  if (!defined($self->{Config})){
    $self->{Config} = $config;
    return undef;
  }

  return $self->{Config}->load($config);
}

sub _getValueFromConfig {
  my $self = shift;
  my $key = shift; 
  my $cluster = shift;
  my $keyWithCluster = $key;

  # no config just bail
  if (!defined($self->{Config})){
    return "";
  }

  # if no cluster is defined use this cluster
  # if that also fails bail unless the cluster is
  # an empty string then do nothing
  if (!defined($cluster)){
    if (!defined($self->getThisCluster())){
      return "";
    }
    $keyWithCluster = $self->getThisCluster().".".$key;
  }
  elsif ($cluster ne ""){
    $keyWithCluster = $cluster.".".$key;
  }

  # get parameter from config
  my $val = $self->{Config}->getParameterValue($keyWithCluster);

  # if no value was found see if the $cluster has an alias to another
  # cluster, if yes attempt to retreive the value from that cluster config
  if (!defined($val)){
    my $aCluster = $self->{Config}->getParameterValue($cluster.".".$self->{ALIAS_TO});
    if (defined($aCluster) && $aCluster ne ""){
      $keyWithCluster = $aCluster.".".$key;
      $val = $self->{Config}->getParameterValue($keyWithCluster);
    }
    if (!defined($val)){
      return "";
    }
  }
  return $val;
}

=head3 getThisCluster 

Gets the cluster that this config is running on aka the cluster
that is considered local

=cut

sub getThisCluster {
    my $self = shift;
    return $self->_getValueFromConfig($self->{THIS_CLUSTER},"");

}

=head3 getEmailNotificationLevel 

Gets the logging levels which should trigger
email notification.

=cut

sub getEmailNotificationLevel {
  my $self = shift;
  return $self->_getValueFromConfig($self->{NOTIFICATION_LEVEL},"");
}

=head3 getNotificationEmail 

Email that notifications should be sent to.  If there
are multiple emails they will be comma separated.

=cut

sub getNotificationEmail {
  my $self = shift;
  return $self->_getValueFromConfig($self->{NOTIFICATION_EMAIL},"");
}

=head3 getNotificationSubject

Gets the subject to use in email notifications.

=cut

sub getNotificationSubject {
  my $self = shift;
  return $self->_getValueFromConfig($self->{NOTIFICATION_SUBJECT},"");
}

=head3 isClusterPartOfThisCluster

Checks if cluster passed in is a local cluster or not.  

my $res = $config->isClusterPartOfThisCluster("foo");

Returns 1 for yes and 0 for no.  

=cut

sub isClusterPartOfThisCluster {
    my $self = shift;
    my $cluster = shift;
    my $thisCluster = $self->getThisCluster();

    # if This.Cluster is undefined or empty string. Fail or
    # if cluster argument is undef
    if (!defined($cluster) || 
        !defined($thisCluster) ||
        $thisCluster eq ""){
       return 0;
    }
   
    # if there is a comma as part of the cluster name just
    # fail the test
    if (index($cluster,',') > -1){
       return 0;
    }

    # return 1 if cluster passed in matches This.Cluster or
    # if the cluster is an element in a comma delimited list
    if ($thisCluster eq $cluster ||
        $thisCluster =~ /,\s*$cluster\s*$/ ||
        $thisCluster =~ /,\s*$cluster\s*,/ ||
        $thisCluster =~ /^\s*$cluster\s*,/){
      return 1;
    }

  return 0;
}

=head3 getScratchDir 

Gets the scratch directory for the cluster

=cut

sub getScratchDir {
   my $self = shift;
   my $cluster = shift;
   return $self->_getValueFromConfig($self->{SCRATCH},$cluster);
}

=head3 getBinDir 

Gets the directory where the panfish binaries reside 
for a given cluster

=cut

sub getBinDir {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{BIN_DIR},$cluster);
}


=head3 getPanfishSleepTime 

Panfish sleep time in seconds

=cut

sub getPanfishSleepTime {
   my $self = shift;
   my $cluster = shift;
   return $self->_getValueFromConfig($self->{PANFISH_SLEEP},$cluster);
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

=head getSubmit

Get path to submit binary for cluster.  For
backwards compatibility code will also look for
old QSUB value if SUBMIT is missing

=cut

sub getSubmit {
    my $self = shift;
    my $cluster = shift;
    my $submitPath = $self->_getValueFromConfig($self->{SUBMIT},$cluster);
    return $submitPath;
}

=head3 getStat

Gets path for program that gets status of jobs

=cut

sub getStat {
    my $self = shift;
    my $cluster = shift;
    
    my $statPath = $self->_getValueFromConfig($self->{STAT},$cluster);
    return $statPath;
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

=head3 getPanfish

Gets the path on the remote cluster to panfish
binary.  This method expects a cluster as a parameter.

my $pan = $foo->getPanfish("gordon_shadow.q");

=cut

sub getPanfish {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{BIN_DIR},$cluster)."/".
           $self->getPanfishBinaryOnly();
}

=head3 getPanfishBinaryOnly

Returns name of binary for Panfish

my $val = $config->getPanfishBinaryOnly();

=cut

sub getPanfishBinaryOnly {
   my $self = shift;
   return $self->{PANFISH};
}



=head3 getPanfishStat

Gets the path on the remote cluster to panfishstat
binary.  This method expects a cluster as a parameter.

my $psub = $foo->getPanfishStat("gordon_shadow.q");

=cut

sub getPanfishStat {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{BIN_DIR},$cluster)."/".
           $self->getPanfishStatBinaryOnly();
}

=head3 getPanfishStatBinaryOnly

Returns name of binary for PanfishStat

my $val = $config->getPanfishStatBinaryOnly();

=cut

sub getPanfishStatBinaryOnly {
   my $self = shift;
   return $self->{PANFISH_STAT};
}


=head3 getPanfishSubmit 

Gets the path on the remote cluster to panfishsubmit
binary.  This method expects a cluster as a parameter.

my $psub = $foo->getPanfishSubmit("gordon_shadow.q");

=cut

sub getPanfishSubmit {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($self->{BIN_DIR},$cluster)."/".
           $self->getPanfishSubmitBinaryOnly();
}


=head3 getPanfishSubmitBinaryOnly

Returns name of binary for PanfishSubmit

my $val = $config->getPanfishSubmitBinaryOnly();

=cut

sub getPanfishSubmitBinaryOnly {
   my $self = shift;
   return $self->{PANFISH_SUBMIT};
}

=head3 getPanfishSetup 

Gets the path on the remote cluster to panfishsetup
binary.  This method expects a cluster as a parameter

my $psub = $foo->getPanfishSetup("gordon_shadow.q");

=cut

sub getPanfishSetup {
 my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{BIN_DIR},$cluster)."/".
           $self->getPanfishSetupBinaryOnly();
}

=head3 getPanfishSetupBinaryOnly

Returns name of binary for PanfishSetup

my $val = $config->getPanfishSetupBinaryOnly();

=cut

sub getPanfishSetupBinaryOnly {
   my $self = shift;
   return $self->{PANFISH_SETUP};
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
the list of clusters passed in to this method.  



my ($skippedClusters,$cList) = $config->getCommaDelimitedClusterList();

or

my ($skippedClusters,$cList) = $config->getCommaDelimitedClusterList("lion_shadow.q,pokey_shadow.q");

=cut

sub getCommaDelimitedClusterList {
    my $self = shift;
    my $clusterList = shift;

    my ($skippedClusters,@cArray) = $self->getClusterListAsArray($clusterList);

    my $cList = "";
    for (my $x = 0; $x < @cArray; $x++){
        if ($cList eq ""){
            $cList = "$cArray[$x]";
        }
        else{
            $cList .= ",$cArray[$x]";
        }
    }
    return ($skippedClusters,$cList);
}

=head3 getClusterListAsArray

Gets array of clusters from the configuration filtered by
the list of clusters passed in to this method.  If the cluster list passed in
has invalid values then those invalid clusters are set in $skippedClusters separated by commas

my ($skippedClusters,$cArray) = $config->getClusterListAsArray();

or

my ($skippedClusters,@cArray) = $config->getClusterListAsArray("lion_shadow.q,pokey_shadow.q");

=cut

sub getClusterListAsArray {
    my $self = shift;
    my $clusterList = shift;

    my $skipCheck = shift;

    my $skippedClusters = undef;

    my $cListFromConfig = $self->_getValueFromConfig($self->{CLUSTER_LIST},"");
    if ($cListFromConfig eq ""){
         my @tmpArr;
         if (defined($clusterList) && defined($skippedClusters) &&
             $skippedClusters == 1){
             my @tmpArr = split(",",$clusterList);
             return (undef,@tmpArr);
         }
         return($clusterList,@tmpArr);
    }

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
        if (defined($cHash{$cArrayFromParam[$x]}) ||
            (defined($skipCheck) && $skipCheck == 1)){
            push(@finalArray,$cArrayFromParam[$x]);
        }
        else {
           if (!defined($skippedClusters)){
              $skippedClusters = $cArrayFromParam[$x];
           }
           else {
              $skippedClusters .= ",".$cArrayFromParam[$x];
           }
        }
    }
    return ($skippedClusters,@finalArray);
}

=head3 getLineCommand

Returns the line program name

=cut

sub getLineCommand {
    my $self = shift; # technically don't need to bother to do this
    return "$Bin/".$self->{LINE_COMMAND};
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


=head3 getPanfishJobRunner

Gets the run job script for the cluster specified

=cut

sub getPanfishJobRunner {
    my $self = shift;
    my $cluster = shift;

    return $self->_getValueFromConfig($self->{BIN_DIR},$cluster)."/".
           $self->getPanfishJobRunnerBinaryOnly();
}


=head3 getPanfishJobRunnerBinaryOnly

Gets the name of the panfishjobrunner program

=cut

sub getPanfishJobRunnerBinaryOnly {
    my $self = shift;

    return $self->{PANFISH_JOB_RUNNER};
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

=head3 getIORetryCount

Gets the number of retries that should be attempted for upload/download

=cut

sub getIORetryCount {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{IO_RETRY_COUNT},$cluster);
}

=head3 getIOTimeout

Gets the time to wait before considering upload/down has failed

=cut

sub getIOTimeout {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{IO_TIMEOUT},$cluster);
}

=head3 getIORetrySleep 

Number of seconds to wait before retrying

=cut

sub getIORetrySleep {
     my $self = shift;
     my $cluster = shift;
     return $self->_getValueFromConfig($self->{IO_RETRY_SLEEP},$cluster);
}

=head3 getIOConnectTimeout

Connection time out in seconds

=cut

sub getIOConnectTimeout {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{IO_CONNECT_TIMEOUT},$cluster);
}


=head3 getAccount

Gets account to charge jobs to for cluster

=cut

sub getAccount {
    my $self = shift;
    my $cluster = shift;
    return $self->_getValueFromConfig($self->{ACCOUNT},$cluster);
}

=head3 getWallTime 

Gets walltime to set for job

=cut

sub getWallTime {
   my $self = shift;
   my $cluster = shift;
   return $self->_getValueFromConfig($self->{WALLTIME},$cluster);
}

=head3 getCommandsFileSuffix

Gets the suffix to be used for command files.
Value will include prefix period.

=cut

sub getCommandsFileSuffix {
  my $self = shift;
  return $self->{COMMANDS_FILE_SUFFIX};
}


=head3 getPsubFileSuffix

Gets the suffix to be used for psub files.
Value will include prefix period.

=cut

sub getPsubFileSuffix {
  my $self = shift;
  return $self->{PSUB_FILE_SUFFIX};
}

=head3 getRealJobFileDir 

Gets the directory path where real job files
run by the LRMS's are stored.  This path
is under the database dir for the given
cluster

=cut

sub getRealJobFileDir {
  my $self = shift;
  my $cluster = shift;

  return $self->getDatabaseDir($cluster)."/".
         $self->{REAL_JOB_FILE_DIR};
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


=head3 getConfigForCluster 

Outputs in an array a configuration for a given cluster.  This
configuration can be written to a panfish.config file and sets

this.cluster=CLUSTER
cluster.list=CLUSTER

CLUSTER.q.host=
.
.
.

=cut

sub getConfigForCluster {
    my $self = shift;
    my $cluster = shift;
    my @config = ();

    if (!defined($cluster)){
       return @config;
    }

    push(@config,$self->{THIS_CLUSTER}."=".$cluster);
    push(@config,$self->{CLUSTER_LIST}."=".$cluster);
    push(@config,$cluster.".".$self->{ENGINE}."=".$self->getEngine($cluster));
    push(@config,$cluster.".".$self->{BASE_DIR}."=".$self->getBaseDir($cluster));
    push(@config,$cluster.".".$self->{DATABASE_DIR}."=".$self->getDatabaseDir($cluster));
    push(@config,$cluster.".".$self->{SUBMIT}."=".$self->getSubmit($cluster));
    push(@config,$cluster.".".$self->{STAT}."=".$self->getStat($cluster));
    push(@config,$cluster.".".$self->{BIN_DIR}."=".$self->getBinDir($cluster));
    push(@config,$cluster.".".$self->{MAX_NUM_RUNNING_JOBS}."=".$self->getMaximumNumberOfRunningJobs($cluster));
    push(@config,$cluster.".".$self->{PANFISH_SLEEP}."=".$self->getPanfishSleepTime($cluster));
    push(@config,$cluster.".".$self->{SCRATCH}."=".$self->getScratchDir($cluster));
    push(@config,$cluster.".".$self->{PANFISH_VERBOSITY}."=".$self->getPanfishVerbosity($cluster));
    push(@config,$cluster.".".$self->{PANFISHSUBMIT_VERBOSITY}."=".$self->getPanfishSubmitVerbosity($cluster));

    return @config;
}

1;

__END__

=head1 AUTHOR

Panfish::PanfishConfig is written by Christopher Churas<lt>churas@ncmir.ucsd.edu<gt>.

=cut


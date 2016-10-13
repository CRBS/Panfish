package Panfish::JobToClusterAssigner;

use Cwd;
use strict;
use English;
use warnings;
use Panfish::JobState;

=head1 NAME

Panfish::JobToClusterAssigner -- Assigns Jobs to clusters

=head1 SYNOPSIS

  use Panfish::JobToClusterAssigner;
  my $logger = Panfish::Logger->new();
  my $jobDb = Panfish::FileJobDatabase->new(...)
  my $assigner = Panfish::JobToClusterAssigner->new($logger,$jobDb);

  $assigner->assignJobs($args);
  					   
					   
=head1 DESCRIPTION

Instances of this class submit a job using command line program.

					   
=head1 METHODS


=head3 new

  Creates new Panfish::JobToClusterAssigner
  my $assigner = Panfish::JobToClusterAssigner->new($logger,$jobDb);

=cut 

sub new {
    my $class = shift;
    my $self = {
        Config => shift,
        JobDb         => shift,
        Logger        => shift,
        DEFAULT_MAX_QUEUED_JOBS => 10000
	};
    return bless ($self,$class);
}

=head3 assignJobs

Looks for any unassigned jobs. If found checks
for any clusters that have free slots and assigns
those jobs to those clusters. Returns number of assigned jobs

=cut

sub assignJobs {
  my $self = shift;
  
  # sort unassigned jobs by file age with oldest first.
  my @jobs = $self->{JobDb}->getJobsByClusterAndState($self->{Config}->getUnassignedCluster(), Panfish::JobState->SUBMITTED());

  if (@jobs <= 0){
    $self->{Logger}->debug("No jobs to assign");
    return 0;
  }

  # Look for any open slots in clusters
  # Get a hash table of cluster => # free slots
  my $ht = $self->_getHashOfOpenSlotsPerCluster();
 
  for (my $x = 0; $x < @jobs; $x++){
    my ($skippedClusters,$cArray) = $self->{Config}->getClusterListAsArray($jobs[$x]->getRawCluster());
    for (my $y = 0; $y < @{$cArray}; $y++){
      if ($ht->{${$cArray}[$y]} > 0){
        $self->_moveJobToCluster($jobs[$x],${$cArray}[$y]);
        $ht->{${$cArray}[$y]}--;
        $y = @{$cArray};
      }
    }
  }
}

sub _moveJobToCluster {
  my $self = shift;
  my $job = shift;
  my $cluster = shift;
  my $taskStepSize = "1";
  my $taskLast = "1";
  
  my $baseDir = "";
  if ($self->{Config}->isClusterPartOfThisCluster($cluster) == 0){
    $baseDir = $self->{Config}->getBaseDir($cluster);
  }

  my $scratch = $self->{Config}->getScratchDir($cluster);
  my $stdErrOut = $self->_getStandardErrorOutput($job->getRawOutPath(),
                                                 $job->getRawErrorPath(),
                                                $job->getRawWriteOutputLocal());

  my $exportableTaskId = $job->getTaskId();
  if (!defined($exportableTaskId)){
    $exportableTaskId = "";
  }


  my $command = "export PANFISH_BASEDIR=\"".$baseDir."\";".
                "export PANFISH_SCRATCH=\"".$scratch."\";".
                "export JOB_ID=\"".$job->getJobId()."\";".
                "export SGE_TASK_ID=\"".$exportableTaskId."\";".
                "export SGE_TASK_STEPSIZE=\"".$taskStepSize."\";".
                "export SGE_TASK_LAST=\"".$taskLast."\";".
                "\$PANFISH_BASEDIR".$job->getRawCommand()." $stdErrOut";

  my $walltime = $self->_getWallTimeForJob($cluster,$self->{Config},
                                           $job->getRawWalltime());

  my $account = $self->_getAccountForJob($cluster,$self->{Config},
                                         $job->getRawAccount());

  my $batchFactor = $self->_getBatchFactorForJob($cluster,$self->{Config},
                                                 $job->getRawBatchfactor());

  $job->setCluster($cluster);
  $job->setCurrentWorkingDirectory(getcwd());
  $job->setCommand($command);
  $job->setState(Panfish::JobState->SUBMITTED());
  $job->setBatchFactor($batchFactor);
  $job->setWallTime($walltime);
  $job->setAccount($account);

  return $self->{JobDb}->update($job);
}


=head3 _getHashOfOpenSlotsPerCluster

Internal, Creates a hash table where the key is the cluster
and the value is the number of additional jobs the cluster
can consume. This is calculated by taking the number of
running/queued jobs and subtracting it from the maximum
number of jobs allowed to be queued on cluster. 

=cut
sub _getHashOfOpenSlotsPerCluster {
  my $self = shift;
  my %clusterSlotHash = ();
 
  # iterate through all clusters and for each cluster count up
  # total number of jobs in incomplete state and subtract from
  # max value put this in a hash with negative values set to 0
  my ($skipped,@clist) = $self->{Config}->getClusterListAsArray();
  if (@clist == 0){
    $self->{Logger}->warn("Cluster list is empty");
    return \%clusterSlotHash;
  }

  my $count = 0;
  my $key;
  my $value;
  for (my $x = 0; $x < @clist; $x++){
    $self->{Logger}->debug("Checking cluster for incomplete job count: ".
                           $clist[$x]);
    my $ht = $self->{JobDb}->getHashtableSummaryOfAllNotCompleteForCluster($clist[$x]);
    $count = 0;
    while (($key, $value) = each(%{$ht})){
      $count += $value;
    }
    my $max_queued = $self->{Config}->getMaximumNumberOfQueuedJobs($clist[$x]);
    if ($max_queued eq ""){
      $max_queued = $self->{DEFAULT_MAX_QUEUED_JOBS};
    }
    my $open_cnt = $max_queued - $count;
    if ($open_cnt < 0 ){
      $open_cnt = 0;
    }
    $clusterSlotHash{$clist[$x]} = $open_cnt;
  }
  return \%clusterSlotHash;
}


=head3 _getStandardErrorOutput 

Generates correct redirects of standard error and output

If writeOutputLocalArg is not defined just redirect stderr and 
stdout to files specified by the user with $PANFISH_BASEDIR prefix

If writeOutputLocalArg is defined then redirect stderr and stdout 
to files under $PANFISH_SCRATCH and add mv commands to put them in 
the correct location upon script completion.  If stdout or stderr 
is /dev/null. The $PANFISH_SCRATCH and PANFISH_BASEDIR is skipped 
and so is the mv command.

=cut

sub _getStandardErrorOutput {
    my $self = shift;
    my $stdout = shift;
    my $stderr = shift;
    my $writeOutputLocalArg = shift;

    my ($stdOutRedirect,$stdOutMv) = $self->_getRedirectOutput(">",
                            $stdout,"out",$writeOutputLocalArg);

    my ($stdErrRedirect,$stdErrMv) = $self->_getRedirectOutput("2>",
                            $stderr,"err",$writeOutputLocalArg);

    return $stdOutRedirect." ".$stdErrRedirect.$stdOutMv.$stdErrMv;
}

sub _getRedirectOutput {
  my $self = shift;
  my $redirectSymbol = shift;
  my $outFile = shift;
  my $suffix = shift;
  my $writeOutputLocalArg = shift;
  # if no redirect is specified perform no redirect
  if ($outFile eq ""){
    return (" ","");
  }

  if ($outFile eq "/dev/null"){
    return ($redirectSymbol." ".$outFile,"");
  }

  if (!defined($writeOutputLocalArg)){
    return ($redirectSymbol." \$PANFISH_BASEDIR".$outFile,"");
  }

  return ($redirectSymbol." \$PANFISH_SCRATCH/\$JOB_ID.\$SGE_TASK_ID.$suffix",";/bin/mv \$PANFISH_SCRATCH/\$JOB_ID.\$SGE_TASK_ID.$suffix \$PANFISH_BASEDIR$outFile");
}

sub _getBatchFactorForJob {
   my $self = shift;
   my $cluster = shift;
   my $config = shift;
   my $batchFactorArg = shift;

   if (!defined($batchFactorArg)){
       return undef;
   }
   return $self->_getArgumentValueForCluster($cluster,$batchFactorArg);
}

sub _getAccountForJob {
    my $self = shift;
    my $cluster = shift;
    my $config = shift;
    my $accountArg = shift;

    if (!defined($accountArg)){
        return $config->getAccount($cluster);
    }

    my $account = $self->_getArgumentValueForCluster($cluster,$accountArg);

    if (defined($account)){
        return $account;
    }
    return $config->getAccount($cluster);
}

sub _getWallTimeForJob {
    my $self = shift;
    my $cluster = shift;
    my $config = shift;
    my $wallTimeArg = shift;

    if (!defined($wallTimeArg)){
        return $config->getWallTime($cluster);
    }

    my $walltime = $self->_getArgumentValueForCluster($cluster,$wallTimeArg);

    if (defined($walltime)){
        return $walltime;
    }
    return $config->getWallTime($cluster);
}

sub _getArgumentValueForCluster {
    my $self = shift;
    my $cluster = shift;
    my $arg = shift;

    my $default = undef;
    my @split = split(",",$arg);

    for (my $x = 0; $x < @split; $x++){
       if ($split[$x]=~m/^(.*)::(.*)$/){
           if ($1 eq $cluster){
              return $2;
           }
       }
       else {
         $default = $split[$x];
       }
    }
    return $default;
}








1;

__END__

=head1 AUTHOR

Panfish::JobToClusterAssigner is written by Christopher Churas <churas@ncmir.ucsd.edu>

=cut

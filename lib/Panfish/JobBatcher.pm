package Panfish::JobBatcher;

use strict;
use English;
use warnings;

use Panfish::JobState;

=head1 SYNOPSIS
   
Panfish::JobBatcher -- Batches individual jobs to prepare them for running on remote clusters

=head1 DESCRIPTION

Batches Panfish Jobs

=head1 METHODS

=head3 new

Creates new instance of JobBatcher object

my $job = Panfish::JobBatcher->new($config,$jobdb,$logger,
                                   $cmdCreator,$psubCreator,$jobHashFac,
                                   $pathSorter)

=cut

sub new {
  my $class = shift;
  my $self = {
     Config          => shift,
     JobDb           => shift,
     Logger          => shift,
     CmdCreator      => shift,
     PsubCreator     => shift,
     JobHashFactory  => shift,
     PathSorter      => shift
  };

  my $blessedself = bless($self,$class);
  return $blessedself;
}

=head3 batchJobs

This method does several things.  First it finds all submitted jobs
for the cluster passed in and then batches them into bundles suitable to 
run on the cluster they are designed to run on.  The code then writes
these batches out to job files in under the cwd for that job.  In addition,
a template file is copied to the cwd for that job and adjusted to work
for the cluster.  Once complete the jobs are set to batched state.

my $res = $batcher->batchJobs($cluster);

=cut

sub batchJobs {
  my $self = shift;
  my $cluster = shift;

  if (!defined($cluster)){
    $self->{Logger}->error("Cluster is not set");
    return "Cluster is not set";
  }

  my $res;
    
  # builds a hash where key is job id and value is an array
  # of jobs with that job id
  my $jobHashByPath = $self->_buildJobHash($cluster); 

  # no jobs to process
  if (!defined($jobHashByPath)){
    return undef;
  }

  my @keys = keys %$jobHashByPath;

  my @sortedJobPaths = $self->{PathSorter}->sort(\@keys);

  if (!@sortedJobPaths){
    return undef;
  }
 
  my $jobPath;
  # iterate through each job array
  foreach $jobPath (@sortedJobPaths){
   
    # sort the job array by task id
    my @sortedJobs = sort {$self->_sortJobsByTaskId } @{$jobHashByPath->{$jobPath}};

    # check if it is okay to submit these jobs
    while ($self->_isItOkayToSubmitJobs($cluster,\@sortedJobs) eq "yes"){

      # grab a batchable set of those jobs 
      my @batchableJobs = $self->_createBatchableArrayOfJobs($cluster,
                                                             \@sortedJobs);

      # generate a command file for those jobs
      $res = $self->{CmdCreator}->create($cluster,\@batchableJobs);
      if (defined($res)){
        $self->{Logger}->error("Unable to create commands file : $res");
        next;
      }

      # generate a psub file
      $res = $self->{PsubCreator}->create($cluster,\@batchableJobs); 
      if (defined($res)){
         $self->{Logger}->error("Unable to create psub file : $res");
         next;
      }
    
      # update batched jobs in database
      $res = $self->{JobDb}->updateArray(\@batchableJobs);
      if (defined($res)){
        $self->{Logger}->error("Unable to update jobs in database : $res");
        next;
      }

      $self->{Logger}->info("Batched ".@batchableJobs.
                            " jobs on $cluster with base id: ".
                            $batchableJobs[0]->getJobAndTaskId());
    } 
  }
  return undef;
}

# 
# Given an array of jobs this method
# will pop off elements from that
# array and put into a new array if
# the jobs per node is less then the
# array size leaving extra jobs on that
# array
# the method then returns this new array
#

sub _createBatchableArrayOfJobs {
  my $self = shift;
  my $cluster = shift;
  my $jobsArrayRef = shift;

  # Since this is called after checking it is assumed
  # this config value is set
  my $jobsPerNode = $self->{Config}->getJobsPerNode($cluster);

  # pop off from the jobsArrayRef until we hit jobs per node limit
  # OR we run out of jobs in the array reference.
  # Assuming there are jobs initially since this is a protected call
  my $job;
  my $jobCount = 0;

  my @batchableJobs;

  while($jobCount < $jobsPerNode){
    $job = shift @{$jobsArrayRef};
    if (!defined($job)){
      last;
    }
    $jobCount += $self->_getBatchFactorForJob($job);
    push(@batchableJobs,$job);   
  }

  return @batchableJobs;
}

#
# If the number of jobs is greater then or equal to jobs per node
# for cluster then a "yes" is returned.  Otherwise "no" is returned
# unless every job in the job list has a modification time more then
# Panfish::Config->getJobBatcherOverrideTimeout() seconds old in 
# which case a yes is returned.
#
sub _isItOkayToSubmitJobs {
  my $self = shift;
  my $cluster = shift;
  my $jobs = shift;
    
    
 
  # if there are no jobs then just bail 
  if (!defined($jobs) || @{$jobs} <= 0){
    $self->{Logger}->debug("There are no jobs to submit");
    return "no";
  }

  # count up batch factor for jobs.
  my $jobCount = 0;
  for (my $x = 0; $x < @{$jobs}; $x++){ 
    $jobCount += $self->_getBatchFactorForJob(${$jobs}[$x]);
  }

  my $jobsPerNode = $self->{Config}->getJobsPerNode($cluster);
  if (!defined($jobsPerNode) || $jobsPerNode eq ""){
    $self->{Logger}->error("Jobs per node not set for cluster $cluster : ignoring jobs");
    return "no";
  }

  if ($jobCount >= $jobsPerNode){
    $self->{Logger}->debug("Job count: $jobCount exceeds threshold of ".
                           $self->{Config}->getJobsPerNode($cluster).
                           " for cluster $cluster.  Allowing jobs to".
                           " be submitted");
    return "yes";
  }
    
  my $overrideTimeout = $self->{Config}->getJobBatcherOverrideTimeout($cluster);
  if (!defined($overrideTimeout) || $overrideTimeout eq ""){
    $self->{Logger}->error("Override timeout not set for cluster : $cluster ".
                           ": ignoring jobs");
    return "no";
  }

  my $curTimeInSec = time();

  $self->{Logger}->debug("Current Time $curTimeInSec and Override Time: ".
                         $overrideTimeout);
  for (my $x = 0; $x < @{$jobs};$x++){

    # hack cause we are getting an array of jobs but the first element is not set
    if (!defined(${$jobs}[$x])){
      return "no";
    }

    if ((abs($curTimeInSec - ${$jobs}[$x]->getModificationTime())) < $overrideTimeout){
      $self->{Logger}->debug("Job ".${$jobs}[$x]->getJobAndTaskId()." age is ".
                         abs($curTimeInSec - ${$jobs}[$x]->getModificationTime()).
                                  " seconds which is less then override timeout ".
                                  "of $overrideTimeout seconds : not releasing jobs");
      return "no";
    }
  }
  return "yes";
}

#
#
#
#

sub _getBatchFactorForJob {
  my $self = shift;
  my $job = shift;
   
  my $batchFactor = $job->getBatchFactor();

  if (!defined($batchFactor) || $batchFactor <= 0){
    return 1;
  }
    
  return 1/$batchFactor;
}


#
# Builds a hash of jobs where the key is
# the current working dir and the value in the hash is
# all job objects who share that dir stored
# in an array
# Ex:
#   $hash{jobdir} => {Panfish::Job,Panfish::Job,Panfish::Job};
#
#
sub _buildJobHash {
  my $self = shift;
  my $cluster = shift;
    
  my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                                            Panfish::JobState->SUBMITTED());
  my $numJobs;
  if (!@jobs || @jobs <= 0){
    $numJobs = 0;
  }
  else {
    $numJobs = @jobs;
  }

  $self->{Logger}->debug("Found $numJobs job(s) in ".
                         Panfish::JobState->SUBMITTED()." state for $cluster");

  if ($numJobs <= 0){
    return undef;
  }
  
  my ($jobHashByPath,$error) = $self->{JobHashFactory}->getJobHash(\@jobs);

  return $jobHashByPath;
}


# 
# This function is passed to sort function to
# sort an list of jobs in ascending order by
# job id and task id.
#
sub _sortJobsByTaskId {
  # $a and $b are the jobs
  my $a = $Panfish::JobBatcher::a;
  my $b = $Panfish::JobBatcher::b;

  return $a->compareByJobAndTaskId($b);
}

1;

__END__


=head1 AUTHOR

Panfish::JobBatcher is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


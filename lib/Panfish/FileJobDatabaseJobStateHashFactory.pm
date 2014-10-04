package Panfish::FileJobDatabaseJobStateHashFactory;

use strict;
use English;
use warnings;

use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
Panfish::FileJobDatabaseJobStateHashFactory -- Obtains status of jobs using 
Filesystem Database.  This implementation strips the task id from jobs

=head1 DESCRIPTION

Obtains a hash of job states by querying Filesystem Job Database
building a hash where the key is the job id and the value is
a JobState object

=head1 METHODS

=head3 new

Creates new instance of FileJobDatabaseJobStateHashFactory

=cut

sub new {
   my $class = shift;
   my $self = {
     Config       => shift,
     Logger       => shift,
     JobDb  => shift,
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 getJobStateHash 

Makes calls to Filesystem Job Database to build
a hash of job ids with states.  Where job ids have
task id's stripped off.  Also the resulting states
are either running,done, or failed.  Jobs are set 
to those states based on the following rules.  Jobs
are put in "done" state only if all jobs sharing that jobid 
are done.  Jobs are put in "failed" state only if all jobs
are either in done or failed state.  Finally jobs are in "running"
state only if 1 or more job(s) are in any state other then "done"
or "failed"

=cut

sub getJobStateHash {
  my $self = shift;
  my %jobStatusHash = ();
   
  # iterate through all clusters and
  # build a list of all jobs
  #
  my ($skippedClusters,@cArray) = $self->{Config}->getClusterListAsArray();
  if (!@cArray){
    return \%jobStatusHash;
  }

  for (my $x = 0; $x < @cArray; $x++){

    # get states of all jobs in cluster
    my $jobHash = $self->{JobDb}->getJobStatesByCluster($cArray[$x]);
    
    if (!defined($jobHash)){
      next;
    }    

    # iterate through the jobids, strip off task id and add to new hash
    # replacing done with failed and done & failed with running
    for (my $key = keys(%$jobHash)){

      my $simplifiedJobState = $self->_convertJobStateToRunningDoneFailed($jobHash->{$key});

      $key =~s/\..*//;
      my $theState = $jobStatusHash{$key};

      my $newState = $self->_getNewStateForHashEntry($jobStatusHash{$key},
                                                     $simplifiedJobState);
      if (defined($newState)){
        $jobStatusHash{$key} = $newState;
      }
    }
  }
              
  return \%jobStatusHash;
}

#
# If old state is not defined just return
# the $newState.  Otherwise only return newState
# under the following conditions.
#
# If old state is done and the newState is failed or 
# running then return new state
#
# If old state is failed and newState is running then
# return new state
# 
sub _getNewStateForHashEntry {
  my $self = shift;
  my $oldState = shift;
  my $newState = shift;

  if (!defined($oldState)){
    return $newState;
  }

  if ($oldState eq Panfish::JobState->DONE() &&
      ($newState eq Panfish::JobState->FAILED() ||
       $newState eq Panfish::JobState->RUNNING())){
    return $newState;
  }
  if ($oldState eq Panfish::JobState->FAILED() &&
      $newState eq Panfish::JobState->RUNNING()){
    return $newState;
  }
  return undef; 
}

# 
# Like the function name says it takes the job
# state and converts it to done, failed or running.
# Where running is any state other then done or failed
#
sub _convertJobStateToRunningDoneFailed {
  my $self = shift;
  my $jobState = shift;
  if (!defined($jobState)){
    return Panfish::JobState->RUNNING();
  }
  if ($jobState eq Panfish::JobState->DONE()){
    return Panfish::JobState->DONE();
  } 
  if ($jobState eq Panfish::JobState->FAILED()){
    return Panfish::JobState->FAILED();
  }

  return Panfish::JobState->RUNNING();
}


1;

__END__


=head1 AUTHOR

Panfish::FileJobDatabaseJobStateHashFactory is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


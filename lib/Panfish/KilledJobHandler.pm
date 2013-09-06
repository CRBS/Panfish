package Panfish::KilledJobHandler;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::Logger;
use Panfish::FileJobDatabase;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::KilledJobHandler

=head1 DESCRIPTION

Looks for any killed/deleted shadow jobs and if found makes
sure the real jobs have been deleted from queueing system 
as well

=head1 METHODS

=head3 new

Creates new instance of KilledJobHandler

=cut

sub new {
   my $class = shift;
   my $self = {
     JobDb          => shift,
     Logger         => shift,
     FileUtil       => shift,
     RemoteIO       => shift,
     UploadExcludes => undef
   };

   my @excludeArr;
   push(@excludeArr,"*.stderr");
   push(@excludeArr,"*.stdout");
   push(@excludeArr,"*.commands");
   push(@excludeArr,"*.psub");

   $self->{UploadExcludes} = \@excludeArr;

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 removeKilledJobs

This method takes a cluster as a parameter and looks for jobs in 
killed state for that cluster.  The code then deletes any real
jobs associated with those jobs adjusting state to failed.  How
this is performed varies by what state the given killed job is 
in.  

If the job is in done/failed state nothing is done.

If the job is in submitted state the job is simply moved
to failed state.  

If the job is in batched state the job is moved to failed state 
and the .psub/.command files are removed and all jobs in those 
.psub/.command files are moved back to submitted state.  

If the job is in batchedandchummed state or running state then
a token file is written denoting the request to the batched
job directory.  This token file is then uploaded to the 
remote clusters.


my $res = $watcher->removeKilledJobs($cluster);

=cut

sub removeKilledJobs {
    my $self = shift;
    my $cluster = shift;

    if (!defined($cluster)){
        $self->{Logger}->error("Cluster is not set");
        return "Cluster is not set";
    }

    my $res;
 
    my @killedJobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->KILL());   
  
    if (!@killedJobs){
       $self->{Logger}->debug("No jobs in ".Panfish::JobState->KILL()." state on $cluster");
       return undef;
    } 
    
    $self->{Logger}->debug("Found ".@killedJobs." job(s) in ".Panfish::JobState->KILL()." state on $cluster");
    
    my %dirsToUpload;
                      
    # for each job find the real job in the database
    # and kill any real job its running
    # then move it to failed state
    # and remove the kill job
    #
    my $jobToKill;
    my $killedJobCount = 0;
    for (my $x = 0; $x < @killedJobs; $x++){
       $jobToKill = $self->{JobDb}->getJobByClusterAndId($cluster,
                                     $killedJobs[$x]->getJobId(),
                                     $killedJobs[$x]->getTaskId()); 

       if (!defined($jobToKill)){
          $self->{Logger}->debug("Job to be killed not found: ".
                                 $killedJobs[$x]->getJobAndTaskId().
                                 " deleting kill file and moving on");
       }
       elsif ($jobToKill->getState() eq Panfish::JobState->SUBMITTED()){
          # easy case just move the job to failed and go to next job
          $self->_moveJobToNewState($jobToKill,Panfish::JobState->FAILED());
       }
       elsif ($jobToKill->getState() eq Panfish::JobState->BATCHED()){

           # In this state the job is a commands file with psub file.
           # Step one is to delete botthe psub and commands file
           $self->_deletePsubAndCommandFiles($jobToKill);

           # Then move all other jobs in that commands file back to
           # submitted state. 
           $self->_revertBatchedJobsToSubmittedState($cluster,$jobToKill);

           # Delete the job from the database or move it to failed state
           $self->_moveJobToNewState($jobToKill,Panfish::JobState->FAILED());
       }
       elsif ($jobToKill->getState() eq Panfish::JobState->BATCHEDANDCHUMMED() ||
              $jobToKill->getState() eq Panfish::JobState->QUEUED() ||
              $jobToKill->getState() eq Panfish::JobState->RUNNING()){
           # In this case the job is already remote so we need to drop a token
           # file and let the remote panfish and panfishjobrunner handle it
           # We'll need to record the path cause we'll need to do a minimal number
           # of uploads of these token files to the remote cluster
           my $psubFile = $jobToKill->getPsubFile();
           if ($self->{FileUtil}->runFileTest("-e",$psubFile)){
	           $dirsToUpload{$self->{FileUtil}->getDirname($psubFile)}++;
           }
           else {
              $self->{Logger}->error($psubFile." does not exist on file system for job ".
                                     $jobToKill->getJobAndTaskId());
           }
       }
       else {
        # job is in an unknown state deleting kill file and moving on
        $self->{Logger}->debug("Job ".$killedJobs[$x]->getJobAndTaskId().
                               " in state that requires no action for deletion");
       }
       $self->_deleteKillRequest($killedJobs[$x]);
       $killedJobCount++;
    }

    # For each entry in $dirsToUpload invoke remoteIo uploading
    # the token files to the remote cluster
    while ( my ($theDir, $value) = each(%dirsToUpload) ) {
        $self->{RemoteIO}->upload($theDir,$cluster,$self->{UploadExcludes});
    }    

    $self->{Logger}->info("Handled ".
                          $killedJobCount.
                          " job(s) on $cluster");     
    return undef;
}

#
# Deletes the psub and commands file in job if they exist
#
sub _deletePsubAndCommandFiles {
    my $self = shift;
    my $job = shift;

    my $psubFile = $job->getPsubFile();
    my $cmdFile = $job->getCommandsFile();

    if (defined($psubFile)){
        if (!$self->{FileUtil}->deleteFile($psubFile)){
            $self->{Logger}->error("Error deleting $psubFile");
        }
    }
    else {
        $self->{Logger}->error("No psub file for job: ".$job->getJobAndTaskId());
    }
 
    if (defined($cmdFile)){
        if (!$self->{FileUtil}->deleteFile($cmdFile)){
            $self->{Logger}->error("Error deleting $cmdFile");
        }
    }
    else {
       $self->{Logger}->error("No command file for job: ".$job->getJobAndTaskId());
    }

    return;
}

#
# Looks for all jobs in same state as job passed in that
# share the same psub file.  The function then takes
# those jobs and changes their state back to submitted
# in the database
#
sub _revertBatchedJobsToSubmittedState {
    my $self = shift;
    my $cluster = shift;
    my $job = shift;
    
    my $psubFile = $job->getPsubFile();
    if (!defined($psubFile)){
       $self->{Logger}->error("No psub file found for job: ".$job->getJobAndTaskId());
       return;
    }

    my @jobsInState = $self->{JobDb}->getJobsByClusterAndState($cluster,$job->getState());

    if (!@jobsInState){
       $self->{Logger}->debug("No jobs in ".$job->getState()." to examine for possible moving to ".Panfish::JobState->SUBMITTED()." state");
       return;
    }

    for (my $x = 0; $x < @jobsInState; $x++){
        if ($jobsInState[$x]->getPsubFile() eq $psubFile){
            $self->_moveJobToNewState($jobsInState[$x],Panfish::JobState->SUBMITTED());         
        }
    }
    return; 
}



#
# Updates the state of job passed in to failed
# in database
#
sub _moveJobToNewState {
   my $self = shift;
   my $job = shift;
   my $newState = shift;
   $job->setState($newState);
   my $res = $self->{JobDb}->update($job);
   if (defined($res)){
       $self->{Logger}->warn("Unable to update job ".$job->getJobAndTaskId().
                             " to ".$newState." state");
   }
   return $res;
}

#
# Uses Job Database to delete the kill request job
# If there is a problem invoking the delete operation
# the error is logged and error message from JobDb
# is returned to caller otherwise undef is returned
#
sub _deleteKillRequest {
    my $self = shift;
    my $job = shift;

    my $deleteRes = $self->{JobDb}->delete($job);
    if (defined($deleteRes)){
        $self->{Logger}->warn("Error deleting ".Panfish::JobState->KILL()." job ".
                                 $job->getJobAndTaskId());
    }
    return $deleteRes;
}


1;

__END__


=head1 AUTHOR

Panfish::KilledJobHandler is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


package Panfish::QstatJobWatcher;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::FileJobDatabase;
use Panfish::JobState;
use Panfish::Job;
use Panfish::SGEJobStateHashFactory;
use Panfish::PBSJobStateHashFactory;

=head1 SYNOPSIS
   
  Panfish::QsubJobWatcher -- Watches actual jobs by looking at qstat

=head1 DESCRIPTION

Monitors jobs running on cluster submitted by qsub

=head1 METHODS

=head3 new

Creates new instance of Job object



=cut

sub new {
   my $class = shift;
   my $self = {
     Config       => shift,
     JobDb        => shift,
     Logger       => shift,
     FileUtil     => shift,
     Executor  => shift,
     SGEJobStateFactory => undef,
     PBSJobStateFactory => undef
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   $self->{SGEJobStateHashFactory} = Panfish::SGEJobStateHashFactory->new($self->{Config},$self->{Logger},
                                                                          $self->{Executor});

   $self->{PBSJobStateHashFactory} = Panfish::PBSJobStateHashFactory->new($self->{Config},$self->{Logger},
                                                                          $self->{Executor});

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 setSGEJobStateHashFactory

Sets alternate SGEJobStateHashFactory.

=cut

sub setSGEJobStateHashFactory {
   my $self = shift;
   $self->{SGEJobStateHashFactory} = shift;
}

=head3 setPBSJobStateHashFactory

Sets alternate PBSJobStateHashFactory.

=cut

sub setPBSJobStateHashFactory {
   my $self = shift;
   $self->{PBSJobStateHashFactory} = shift;
}

=head3 checkJobs

This method takes a cluster as a parameter and looks for jobs in 
queued/running state for that cluster.  The code then checks the
cluster for an updated status of those jobs and if they differ
the state of the job is updated.


my $res = $watcher->checkJobs($cluster);

=cut

sub checkJobs {
    my $self = shift;
    my $cluster = shift;

    if (!defined($cluster)){
        $self->{Logger}->error("Cluster is not set");
        return "Cluster is not set";
    }

    if ($cluster ne $self->{Config}->getThisCluster()){
       $self->{Logger}->error("Can only be run on jobs for local cluster");
       return "Can only be run on jobs for local cluster";
    }

    my $res;
    
    my $jobArrayRef = $self->_getJobsInQueuedAndRunningStates($cluster); 
   
 
    if (!defined($jobArrayRef) || @{$jobArrayRef} <= 0){
       $self->{Logger}->debug("No jobs found");
       return undef;
    }
    
    $self->{Logger}->debug("Found ".@{$jobArrayRef}." jobs ");
                          
    
    # get status of all jobs on cluster
    # get back a hash where {qstat job id} => { JobState}
    my $jobStatusHash;
    my $error;  
    if ($self->{Config}->getEngine() eq "SGE"){
        ($jobStatusHash,$error) = $self->{SGEJobStateHashFactory}->getJobStateHash();
    }
    elsif ($self->{Config}->getEngine() eq "PBS") {

        ($jobStatusHash,$error) = $self->{PBSJobStateHashFactory}->getJobStateHash();
    }
    else {
        return "Engine ".$self->{Config}->getEngine()." not supported";
    }

    # Just return if there was an error querying for job stats cause we don't know what
    # is going on
    if (defined($error)){
       $self->{Logger}->error("Unable to get updated Job State Hash.  Not updating any jobs");
       return $error;
    }

    my $jobCount = 0;
  
    my $newState;
    # update database with new status
 
    for (my $x = 0; $x < @{$jobArrayRef}; $x++){
        
        $newState = $jobStatusHash->{${$jobArrayRef}[$x]->getRealJobId()};
        if (!defined($newState)){
           $self->{Logger}->debug("Job ".${$jobArrayRef}[$x]->getRealJobId().
                                 " (".${$jobArrayRef}[$x]->getJobAndTaskId()." shadow id) not found in hash.  Assuming completion.");
           $newState = Panfish::JobState->DONE();
        }
        
        if ($newState ne ${$jobArrayRef}[$x]->getState() && 
            $newState ne Panfish::JobState->UNKNOWN()){
            
            $self->{Logger}->debug("Changing state for job ".${$jobArrayRef}[$x]->getJobAndTaskId().
                                 " (".${$jobArrayRef}[$x]->getRealJobId()." real id) from ".
                                 ${$jobArrayRef}[$x]->getState()." to ".$newState);

             ${$jobArrayRef}[$x]->setState($newState);
            $self->{JobDb}->update(${$jobArrayRef}[$x]);
            $jobCount++;
        }
    }
    $self->{Logger}->info("State updated on ".
                          $jobCount.
                          " job(s) on $cluster");     
    return undef;
}


#
# Gets jobs in queued or running state for cluster passed in
#
#
sub _getJobsInQueuedAndRunningStates {
    my $self = shift;
    my $cluster = shift;
    
    my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->QUEUED());

    $self->{Logger}->debug("Found ".@jobs." in queued state");

    my @rJobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->RUNNING());

    $self->{Logger}->debug("Found ".@rJobs." in running state");    

    push(@jobs,@rJobs);

    return \@jobs;
}


1;

__END__


=head1 AUTHOR

Panfish::QstatJobWatcher is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


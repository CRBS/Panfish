package Panfish::QsubJobSubmitter;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobDatabase;
use Panfish::JobState;
use Panfish::Job;

=head1 SYNOPSIS
   
  Panfish::QsubJobSubmitter -- Submits jobs via qsub

=head1 DESCRIPTION

Submits jobs via qsub

=head1 METHODS

=head3 new

Creates new instance of QsubJobSubmitter



=cut

sub new {
   my $class = shift;
   my $self = {
     Config    => shift,
     JobDb     => shift,
     Logger    => shift,
     FileUtil  => shift,
     Executor  => shift
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 submitJobs

This method takes a cluster as a parameter and looks for jobs in 
submitted state for that cluster.  The code then submits 
those jobs for processing and updates the state of the job to queued.

my $res = $batcher->submitJobs($cluster);

=cut

sub submitJobs {
    my $self = shift;
    my $cluster = shift;

    if (!defined($cluster)){
        $self->{Logger}->error("Cluster is not set");
        return "Cluster is not set";
    }

    my $res;
    
    # builds a hash where key is the psub file psub
    # and value is an array
    # of jobs which will be run by that psub file
    $self->{Logger}->debug("Looking for jobs in ".Panfish::JobState->SUBMITTED().
                           " state for $cluster");

    my @jobs = $self->{JobDb}->getJobsByClusterAndState("",
                Panfish::JobState->SUBMITTED());

    if (!@jobs || !defined($jobs[0])){
        $self->{Logger}->debug("No jobs");
        return undef;
    }
    
    $self->{Logger}->debug("Found ".@jobs." jobs  ");
    
    # submit array of psub files
    my $submittedJobsRef = $self->_submitJobsViaQsub($cluster,\@jobs);
    
    if (@{$submittedJobsRef} <= 0){
        $self->{Logger}->debug("No jobs submitted hmmm...");
        return undef;
    }

    # update database with new status
    $self->{Logger}->debug("Submit succeeded updating database");
 
    for (my $x = 0; $x < @{$submittedJobsRef}; $x++){
        ${$submittedJobsRef}[$x]->setState(Panfish::JobState->QUEUED());
        $self->{JobDb}->update(${$submittedJobsRef}[$x]);
          
    }
    $self->{Logger}->info("Submitted ".@{$submittedJobsRef}." jobs"); 
    
    return undef;
}


#
# 
#
#
#
sub _submitJobsViaQsub {
    my $self = shift;
    my $cluster = shift;
    my $jobsArrayRef = shift;

    my $qsubCmd = $self->{Config}->getClusterQsub($cluster);
    my @submittedJobs;
    my $exit;
    my $cmd;
    for (my $x = 0; $x < @{$jobsArrayRef}; $x++){
        $cmd = "$qsubCmd ".${$jobsArrayRef}[$x]->getCommand();
        $exit = $self->{Executor}->executeCommand($cmd,60);
        if ($exit != 0){
            $self->{Logger}->error("Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
        }
        else {
            #need to parse out the job id from output and set it in the job somehow
            push(@submittedJobs,${$jobsArrayRef}[$x]);
        }
    }
    $self->{Logger}->debug($self->{Executor}->getCommand()." : ".
                           $self->{Executor}->getOutput());
    return \@submittedJobs;
}




1;

__END__


=head1 AUTHOR

Panfish::QsubJobSubmitter is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


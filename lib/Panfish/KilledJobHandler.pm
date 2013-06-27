package Panfish::KilledJobHandler;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
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

Creates new instance of Job object



=cut

sub new {
   my $class = shift;
   my $self = {
     Config     => shift,
     JobDb      => shift,
     Logger     => shift,
     FileUtil   => shift,
     Executor   => shift,
     JobKiller  => shift
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
}

=head3 checkForKilledJobs

This method takes a cluster as a parameter and looks for jobs in 
killed state for that cluster.  The code then deletes any real
jobs associated with those jobs adjusting state to failed.

my $res = $watcher->checkForKilledJobs($cluster);

=cut

sub checkForKilledJobs {
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
    
    $self->{Logger}->debug("Found ".@killedJobs." jobs in ".Panfish::JobState->KILL()." state on $cluster");
                          
    # for each job find the real job in the database
    # and kill any real job its running
    # then move it to failed state
    # and remove the kill job
    #
    my $jobToKill;
    my $killedJobCount = 0;
    for (my $x = 0; $x < @killedJobs; $x++){
       $jobToKill = $self->{JobDb}->getJobByClusterAndId($cluster,$killedJobs[$x]->getJobId(),$killedJobs[$x]->getTaskId()); 
       if (!defined($jobToKill)){
          $self->{Logger}->debug("Job to be killed not found: ".$killedJobs[$x]->getJobAndTaskId()." skipping and moving on");
          next;
       }
       
       $res = $self->{JobKiller}->killJob($cluster,$jobToKill);

       if (defined($res)){
           $self->{Logger}->error("Error killing job ".$jobToKill->getJobAndTaskId());
       }
          
       $jobToKill->setState(Panfish::JobState->FAILED());
       $self->{JobDb}->update($jobToKill);
       $self->{JobDb}->delete($killedJobs[$x]);
       $killedJobCount++;
    }

    $self->{Logger}->info("Cleaned up ".
                          $killedJobCount.
                          " job(s) on $cluster");     
    return undef;
}

1;

__END__


=head1 AUTHOR

Panfish::KilledJobHandler is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


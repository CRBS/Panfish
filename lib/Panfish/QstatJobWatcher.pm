package Panfish::QstatJobWatcher;

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
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

   my $blessedself = bless($self,$class);
   return $blessedself;
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
  
    if ($self->{Config}->getEngine() eq "SGE"){
        $jobStatusHash = $self->_getSGEJobStateHash($jobArrayRef);
    }
    elsif ($self->{Config}->getEngine() eq "PBS") {

        $jobStatusHash = $self->_getPBSJobStateHash($jobArrayRef);
    }
    else {
        return "Engine ".$self->{Config}->getEngine()." not supported";
    }
    my $jobCount = 0;
  
    my $newState;
    # update database with new status
 
    for (my $x = 0; $x < @{$jobArrayRef}; $x++){
        
        $newState = $jobStatusHash->{${$jobArrayRef}[$x]->getRealJobId()};
        if (!defined($newState)){
          # couldnt find job lets assume its done
          ${$jobArrayRef}[$x]->setState(Panfish::JobState->DONE());
          $self->{JobDb}->update(${$jobArrayRef}[$x]);
          $jobCount++;
        }
        elsif ($newState ne ${$jobArrayRef}[$x]->getState() && 
            $newState ne Panfish::JobState->UNKNOWN()){
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


sub getPBSJobStateHash {
    my $self = shift;
    my $jobArrayRef = shift;
    my %jobStatusHash = ();

    my $qstatCmd = $self->{Config}->getQstat()." -u \"*\"";

    my $exit = $self->{Executor}->executeCommand($qstatCmd,60);
    if ($exit != 0){
       $self->{Logger}->error("Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
       return \%jobStatusHash;
    }

    if ($self->{Logger}->isDebugEnabled()){
       $self->{Logger}->debug($self->{Executor}->getOutput());
    }
    my $realJobId;
    my $rawState;
    my @subSplit;
    my @rows = split("\n",$self->{Executor}->getOutput());
    for (my $x = 0; $x < @rows; $x++){

        chomp($rows[$x]);
        if ($rows[$x]=~/^---.*/ ||
            $rows[$x]=~/^Job.*/){
           next;
        }
        
        $rows[$x]=~s/ +/ /g;
        @subSplit = split(" ",$rows[$x]);
         $self->{Logger}->debug("XXXXXXX".$rows[$x]);
        for (my $y = 0; $y < @subSplit; $y++){
           $self->{Logger}->debug("YYY $y - $subSplit[$y]");
        }
        $realJobId = $subSplit[0];
        $realJobId=~s/\..*//;
        $rawState = $subSplit[4];
        $self->{Logger}->debug("Setting hash ".$realJobId." => ($rawState) -> ".$self->_convertStateToJobState($rawState));
        $jobStatusHash{$realJobId}=$self->_convertStateToJobState($rawState);

    }
    return \%jobStatusHash;


}


#
# Calls qstat to get current status of all jobs 
# The code then uses that result to build a hash
# of statuses for each job.
#
#
sub _getSGEJobStateHash {
    my $self = shift;
    my $jobArrayRef = shift;
    my %jobStatusHash = ();
   
    my $qstatCmd = $self->{Config}->getQstat()." -u \"*\"";
    
    my $exit = $self->{Executor}->executeCommand($qstatCmd,60);
    if ($exit != 0){
       $self->{Logger}->error("Unable to run ".$self->{Executor}->getCommand().
                               "  : ".$self->{Executor}->getOutput());
       return \%jobStatusHash;
    }

    if ($self->{Logger}->isDebugEnabled()){
       $self->{Logger}->debug($self->{Executor}->getOutput());
    }

    my $realJobId;
    my $rawState;
    my @subSplit;
    my @rows = split("\n",$self->{Executor}->getOutput());
    for (my $x = 0; $x < @rows; $x++){
 
        chomp($rows[$x]);
        if ($rows[$x]=~/^---.*/ ||
            $rows[$x]=~/^job.*/){
           next;
        }
        $rows[$x]=~s/^ *//;
        $rows[$x]=~s/ +/ /g;
        @subSplit = split(" ",$rows[$x]);
        # $self->{Logger}->debug("XXXXXXX".$rows[$x]);
        #for (my $y = 0; $y < @subSplit; $y++){
        #   $self->{Logger}->debug("YYY $y - $subSplit[$y]");
        #} 
        $realJobId = $subSplit[0];
        $rawState = $subSplit[4];
        $self->{Logger}->debug("Setting hash ".$realJobId." => ($rawState) -> ".$self->_convertStateToJobState($rawState));
        $jobStatusHash{$realJobId}=$self->_convertStateToJobState($rawState);
        
    }
    return \%jobStatusHash;
}


sub _convertStateToJobState {
   my $self = shift;
   my $rawState = shift;

   if ($rawState eq "r" ||
       $rawState eq "hr" ||
       $rawState eq "dr" ||
       $rawState eq "R"){
      return Panfish::JobState->RUNNING();
   }

   if ($rawState eq "Eqw" ||
       $rawState eq "E"){
      return Panfish::JobState->FAILED();
   }

   if ($rawState eq "hqw" ||
       $rawState eq "S" ||
       $rawState eq "qw" ||
       $rawState eq "Q"){
      return Panfish::JobState->QUEUED();
   }
   if ($rawState eq "C"){
      return Panfish::JobState->DONE();
   }

   return Panfish::JobState->UNKNOWN();
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


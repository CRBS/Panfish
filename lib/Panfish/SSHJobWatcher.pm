package Panfish::SSHJobWatcher;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::FileJobDatabase;
use Panfish::JobState;
use Panfish::Job;
use Panfish::JobHashFactory;
=head1 SYNOPSIS
   
  Panfish::SSHJobWatcher -- Watches actual jobs on clusters for completion via ssh calls

=head1 DESCRIPTION

Monitors jobs running on clusters for completion/failure.

=head1 METHODS

=head3 new

Creates new instance of Job object



=cut

sub new {
   my $class = shift;
   my $self = {
     Config         => shift,
     JobDb          => shift,
     Logger         => shift,
     FileUtil       => shift,
     SSHExecutor    => shift,
     JobHashFactory => shift
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

    my $res;
    
    # builds a hash where key is the psub file psub
    # and value is an array
    # of jobs which will be run by that psub file
    $self->{Logger}->debug("Looking for jobs in ".Panfish::JobState->QUEUED()." and ".
                           Panfish::JobState->RUNNING().
                           " state for $cluster");
    my $jobHashByPsubJobId = $self->_buildJobHash($cluster); 

    my $jobCount = 0;
    my @psubArray;
    # Iterate through hash and get list of psub files
    # put into array and pass to submitter
    for my $psubJobId (keys %$jobHashByPsubJobId){
        $jobCount +=  @{$jobHashByPsubJobId->{$psubJobId}};
        push(@psubArray,$psubJobId);
    }
    
    if (@psubArray <= 0){
       $self->{Logger}->debug("No jobs found");
       return undef;
    }
    
    $self->{Logger}->debug("Found ".@psubArray." psub files containing ".
                          $jobCount." jobs");
    
    # get status of all jobs on cluster
    # get back a hash where {psub job id} => { JobState}
   
    my $psubStatusHash = $self->_getPsubJobStateViaSSH($cluster,\@psubArray);

    # either no jobs to check status on or there was a problem.  Either way
    # dont update the database
    if (!defined($psubStatusHash)){
       return undef;
    }
    $jobCount = 0;
    my $psubJobId;
    my $state;
    # update database with new status
 
    for my $psubJobId (keys %$jobHashByPsubJobId){
       # need to handle case from panfishstat where job state is notfound 
        $state = $psubStatusHash->{$psubJobId};
        if ($state ne Panfish::JobState->SUBMITTED() && 
            $state ne ${$jobHashByPsubJobId->{$psubJobId}}[0]->getState() &&
            $state ne Panfish::JobState->UNKNOWN()){
            for (my $x = 0; $x < @{$jobHashByPsubJobId->{$psubJobId}}; $x++){
                 ${$jobHashByPsubJobId->{$psubJobId}}[$x]->setState($state);
                 $self->{JobDb}->update(${$jobHashByPsubJobId->{$psubJobId}}[$x]);
                 $jobCount++;
            }
        }
    }
    $self->{Logger}->info("State updated on ".
                          $jobCount.
                          " job(s) on $cluster"); 
    
    return undef;
}


#
# 
#
#
#
sub _getPsubJobStateViaSSH {
    my $self = shift;
    my $cluster = shift;
    my $psubFileArrayRef = shift;
    my $panfishStat = $self->{Config}->getPanfishStat($cluster);
    my %noJobs;
    
    # set to correct cluster
    $self->{SSHExecutor}->setCluster($cluster);   

    # build echo command to pipe to submitter program via ssh
    # need to get all keys and
    # invoke myqsubstdin.sh like this to minimize ssh activity
    # echo -e "1.qsub\\n2.qsub" | ssh gordon.sdsc.edu panfishsubmit
    my $echoArgs = "";
    for (my $x = 0; $x < @{$psubFileArrayRef};$x++){
       if ($echoArgs eq ""){
           $echoArgs = "${$psubFileArrayRef}[$x]";
       }
       else {
           $echoArgs .= "\\\\n${$psubFileArrayRef}[$x]";
       }
    }

    if ($echoArgs eq ""){
        $self->{Logger}->debug("No jobs to check");
        return undef;
    }

    my $exit;
    my $cmd;
    my $state;
    $self->{SSHExecutor}->enableSSH();

    $self->{SSHExecutor}->setStandardInputCommand("/bin/echo -e \"$echoArgs\"");

    $exit = $self->{SSHExecutor}->executeCommand($panfishStat,60);
    if ($exit != 0){
        $self->{Logger}->error("Unable to run ".$self->{SSHExecutor}->getCommand().
                               "  : ".$self->{SSHExecutor}->getOutput());
         return undef;
    }
    $self->{Logger}->debug($self->{SSHExecutor}->getCommand()." : ".
                           $self->{SSHExecutor}->getOutput());
    
    my %psubJobStatusHash =();
    # gotta parse the output and build a hashtable where the
    # key is the job id and the value is the state of the job
    my @rows = split("\n",$self->{SSHExecutor}->getOutput());
    for (my $x = 0; $x < @rows; $x++){
        chomp($rows[$x]);
        if ($rows[$x]=~/^(.*)=(.*)$/){
            $state = $2;
            # if the remote state is batchedandchumed still set the
            # state to queued.  it just means on the remote side that
            # they have yet to submit the job.
            if ($state eq Panfish::JobState->BATCHEDANDCHUMMED()){
                $state =  Panfish::JobState->QUEUED();
            }
            $psubJobStatusHash{$1} = $state;
        }
    }

    return \%psubJobStatusHash;
}



#
# Builds a hash of jobs where the key is
# the directory where the psub file resides 
# and the value in the hash is
# all job objects who share that same directory
# for their psub files
#
# Ex:
#   $hash{"/home/foo/blah/1.1.psub"} => {Panfish::Job,Panfish::Job,Panfish::Job};
#
#
sub _buildJobHash {
    my $self = shift;
    my $cluster = shift;
    
    my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->QUEUED());

    if (!@jobs){
        $self->{Logger}->debug("No jobs in ".Panfish::JobState->QUEUED()."state for $cluster");
    }   
    

    my @rJobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->RUNNING());

    if (!@rJobs){
        $self->{Logger}->debug("No jobs in ".Panfish::JobState->RUNNING()." state for $cluster");
    }
    else {
        push(@jobs,@rJobs);
    }

    my ($jobHashByPsubId,$error) = $self->{JobHashFactory}->getJobHash(\@jobs);
    return $jobHashByPsubId;
}


1;

__END__


=head1 AUTHOR

Panfish::SSHJobWatcher is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


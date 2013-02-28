package Panfish::JobBatcher;

use strict;
use English;
use warnings;

use Panfish::FileUtil;
use Panfish::PanfishConfig;
use Panfish::Logger;
use Panfish::JobDatabase;
use Panfish::JobState;
use Panfish::Job;
use Panfish::FileReaderWriterImpl;

=head1 SYNOPSIS
   
  Panfish::JobBatcher -- Batches individual jobs to prepare them for running on remote clusters

=head1 DESCRIPTION

Batches Panfish Jobs

=head1 METHODS

=head3 new

Creates new instance of Job object

my $job = Panfish::Job->new()

=cut

sub new {
   my $class = shift;
   my $self = {
     Config        => shift,
     JobDb         => shift,
     Logger        => shift,
     FileUtil      => shift,
     Writer        => shift
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
        if (defined($self->{Logger})){
            $self->{Logger}->error("Cluster is not set");
        }
        return "Cluster is not set";
    }
    my $res;
    my $jobHashById = $self->_buildJobHash($cluster); 
    my @sortedJobs; 
    my $jobsPerNode = $self->{Config}->getJobsPerNode($cluster);
    for my $jobId (keys %$jobHashById){
        @sortedJobs = sort {$self->_sortJobsByTaskId } @{$jobHashById->{$jobId}};
        while ($self->_isItOkayToSubmitJobs($cluster,@sortedJobs) eq "yes"){
             my $commandFile = "";
             my $jobsToBatch = @sortedJobs;
             if ($jobsPerNode < $jobsToBatch){
                 $jobsToBatch = $jobsPerNode;
             }
             if (defined($self->{Logger})){
                  $self->{Logger}->debug("Batching $jobsToBatch jobs");

             }
             for (my $x = 0; $x < $jobsToBatch; $x++){
                 my $job = shift @sortedJobs;
                 # use the first job to create the cluster directory
                 # and initialize the command file
                 if ($x == 0){
                     my $commandDir = $job->getCurrentWorkingDir()."/".$cluster;
                     if (! -d $commandDir){
                         if (!mkdir($commandDir)){
                             if (defined($self->{Logger})){
                                 $self->{Logger}->error("There was a problem making dir $commandDir");
                             }
                             return "Problem creating $commandFile";
                         }
                     }
                 
		     $commandFile = $commandDir."/".$job->getJobId().".".
                                    $job->getTaskId();
                     $res = $self->{Writer}->openFile(">$commandFile");
                     if (defined($res)){ 
                         if (defined($self->{Logger})){
                             $self->{Logger}->error("There was a problem opening file : $commandFile");
                         }
                         return "Problem opening file $commandFile";
                     }
                 }

                 # pop off up to $jobsPerNode and write them to a command file
                 print "before $x\n";
                 print "hahaha $x ".$job->getJobId()."\n";
                 $self->{Writer}->write($job->getCommand()."\n");
             
            }
            $self->{Writer}->close();

            # generate a psub file
            

            # update batched jobs in database
             
        } 
    }
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
    my @jobs = shift;
    
    
    if (@jobs >= $self->{Config}->getJobsPerNode($cluster)){
        return "yes";
    }
    if (@jobs <= 0){
        return "no";
    }
    print "length:  ".@jobs."\n";
    my $curTimeInSec = time();
    my $overrideTimeout = $self->{Config}->getJobBatcherOverrideTimeout($cluster);
    for (my $x = 0; $x < @jobs;$x++){

       # hack cause we are getting an array of jobs but the first element is not set
       if (!defined($jobs[$x])){
            return "no";
       }
       if ((abs($curTimeInSec - $jobs[$x]->getModificationTime())) < $overrideTimeout){
           return "no";
       }
    }
    return "yes";
}

sub _buildJobHash {
    my $self = shift;
    my $cluster = shift;
    
    my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->SUBMITTED());

    if (!@jobs){
        if (defined($self->{Logger})){
            $self->{Logger}->error("Error getting jobs from database");
        }
        return undef;
    }
    my %jobHashById = ();

    for (my $x = 0; $x < @jobs; $x++){
        if (defined($jobs[$x])){
            push(@{$jobHashById{$jobs[$x]->getJobId()}},$jobs[$x]);
        }
    }
    return \%jobHashById;
}


sub _sortJobsByTaskId {
   # $a and $b are the jobs
   my $a = $Panfish::JobBatcher::a;
   my $b = $Panfish::JobBatcher::b;
   if ($a->getJobId() < $b->getJobId()){
       return -1;
   }    
   if ($a->getJobId() > $b->getJobId()){
       return 1;
   }

   return $a->getTaskId() <=> $b->getTaskId();
}

1;

__END__


=head1 AUTHOR

Panfish::JobBatcher is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut


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
     Config              => shift,
     JobDb               => shift,
     Logger              => shift,
     FileUtil            => shift,
     Reader              => shift,
     Writer              => shift,
     COMMANDS_FILE_SUFFIX => ".commands",
     PSUB_FILE_SUFFIX    => ".psub"
   };
 
   if (!defined($self->{Logger})){
       $self->{Logger} = Panfish::Logger->new();
   }

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
    $self->{Logger}->debug("Building job hash for $cluster");
    my $jobHashById = $self->_buildJobHash($cluster); 

    my @sortedJobs;
 
    # iterate through each job array
    for my $jobId (keys %$jobHashById){

        # sort the job array by task id
        @sortedJobs = sort {$self->_sortJobsByTaskId } @{$jobHashById->{$jobId}};

        # check if it is okay to submit these jobs
        while ($self->_isItOkayToSubmitJobs($cluster,\@sortedJobs) eq "yes"){

             # grab a batchable set of those jobs 
             my @batchableJobs = $self->_createBatchableArrayOfJobs($cluster,
                                                                    \@sortedJobs);

             # generate a command file for those jobs
             $self->_createCommandFileForJobs($cluster,\@batchableJobs);

             # generate a psub file
             $self->_createPsubFileForJobs($cluster,\@batchableJobs);            

             # update batched jobs in database
             $self->{JobDb}->updateArray(\@batchableJobs);

             $self->{Logger}->info("Batched ".@batchableJobs.
                                   " jobs on $cluster with base id: ".
                                   $batchableJobs[0]->getJobId().".".
                                   $batchableJobs[0]->getTaskId());
        } 
    }
}


sub _createPsubFile {
    my $self = shift;
    my $cluster = shift;
    my $commandsFile = shift;
    my $name = shift;
    # take commands File and strip off .commands suffix and replace with .psub
    my $psubFile = $commandsFile;
    $psubFile=~s/$self->{COMMANDS_FILE_SUFFIX}$/$self->{PSUB_FILE_SUFFIX}/;
        

    # read in template file and replace tokens and
    # write out as psub file
    my $res = $self->{Reader}->openFile($self->{Config}->getJobTemplateDir()."/".
                              $cluster);
    if (defined($res)){
        $self->{Logger}->error("Unable to open :".$self->{Config}->getJobTemplateDir()."/".
                              $cluster);
        return undef;
    }
   
    $self->{Logger}->debug("Creating psub file: $psubFile");
    $res = $self->{Writer}->openFile(">$psubFile");
    if (defined($res)){
        $self->{Logger}->error("There was a problem opening file : $commandsFile");
        return undef;
    }

    my $remoteBaseDir = $self->{Config}->getClusterBaseDir($cluster);

    my $runJobScript = $self->{Config}->getClusterRunJobScript($cluster);
    
    my $jobFileDir = $self->{FileUtil}->getDirname($psubFile);

    $self->{Logger}->debug("Job file dir: $jobFileDir");

    my $line = $self->{Reader}->read();
    while(defined($line)){
        chomp($line);
        $line=~s/\@PANFISH_JOB_STDOUT_PATH\@/$remoteBaseDir$psubFile.stdout/g;
        $line=~s/\@PANFISH_JOB_STDERR_PATH\@/$remoteBaseDir$psubFile.stderr/g;
        $line=~s/\@PANFISH_JOB_NAME\@/$name/g;
        $line=~s/\@PANFISH_JOB_CWD\@/$remoteBaseDir$jobFileDir/g;
        $line=~s/\@PANFISH_RUN_JOB_SCRIPT\@/$runJobScript/g;
        $line=~s/\@PANFISH_JOB_FILE\@/$remoteBaseDir$commandsFile/g;

        $self->{Writer}->write($line."\n");

        $line = $self->{Reader}->read();
    } 
      
    $self->{Reader}->close();
    $self->{Writer}->close();

    # give the psub file execute permission for users and groups
    $self->{FileUtil}->makePathUserGroupExecutableAndReadable($psubFile);
    return $psubFile;
}


#
# Given the jobs make a psub file
#
#
#

sub _createPsubFileForJobs {
    my $self = shift;
    my $cluster = shift;
    my $jobsArrayRef = shift;

    if (@{$jobsArrayRef}<=0){
        return "No jobs to generate a psub file for";
    }

    my $job;
    my $commandsFile;
    my $psubFile;
    for (my $x = 0; $x < @{$jobsArrayRef}; $x++){
        $job = ${$jobsArrayRef}[$x];
  
        # for the first job get the commands file and
        # write out the psub file
        # set that psub file path in every job
        if ($x == 0){
            $commandsFile = $job->getCommandsFile();

            if (!defined($commandsFile) || 
                ! -f $commandsFile){
                 return "No commands file set or invalid path";
            }

            $psubFile = $self->_createPsubFile($cluster,$commandsFile,
                                               $job->getJobName());
        }
        # set the psub file for each job
        $job->setPsubFile($psubFile);

        # set state of job to batched
        $job->setState(Panfish::JobState->BATCHED());
     }
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

    my $jobsPerNode = $self->{Config}->getJobsPerNode($cluster);

    # pop off from the jobsArrayRef until we hit jobs per node limit
    # OR we run out of jobs in the array reference.
    my $job = shift @{$jobsArrayRef};
    my @batchableJobs;
    while(defined($job) && @batchableJobs < $jobsPerNode){
        push(@batchableJobs,$job);
        $job = shift @{$jobsArrayRef};
    }

    return @batchableJobs;
}

sub _createCommandFileForJobs {
    my $self = shift;
    my $cluster = shift;
    my $jobsArrayRef = shift;
    my $commandFile = undef;
    for (my $x = 0; $x < @{$jobsArrayRef}; $x++){
               
        my $job = ${$jobsArrayRef}[$x];
        if (!defined($job)){
            $self->{Logger}->error("Job # $x pulled from array is not defined. wtf");
            return "Undefined job found";
        }
        # use the first job to create the cluster directory
        # and initialize the command file
        if ($x == 0){
            my $commandDir = $job->getCurrentWorkingDir()."/".$cluster;

            $self->{Logger}->debug("Checking to see if command directory: $commandDir exists");

            if (! -d $commandDir){
                $self->{Logger}->debug("Creating directory command directory: $commandDir");
            
                if (!mkdir($commandDir)){
                    $self->{Logger}->error("There was a problem making dir: $commandDir");
                    return "Unable to make directory $commandDir";
                }
            }
            $commandFile = $commandDir."/".$job->getJobId().".".
                           $job->getTaskId().$self->{COMMANDS_FILE_SUFFIX};

            $self->{Logger}->debug("Creating command file:  $commandFile");
            my $res = $self->{Writer}->openFile(">$commandFile");
            if (defined($res)){
                $self->{Logger}->error("There was a problem opening file : $commandFile");
                return "Unable to open file $commandFile";
            }
        }       
        $self->{Writer}->write($job->getCommand()."\n");
        $job->setCommandsFile($commandFile);
    }
    $self->{Writer}->close();
    return undef;
}

# sub _create



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
    
    
    if (@{$jobs} >= $self->{Config}->getJobsPerNode($cluster)){
        return "yes";
    }
    if (@{$jobs} <= 0){
        return "no";
    }
    
    my $curTimeInSec = time();
    my $overrideTimeout = $self->{Config}->getJobBatcherOverrideTimeout($cluster);
    if (!defined($overrideTimeout)){
       $self->{Logger}->error("Override timeout not set for cluster : $cluster : ignoring jobs");
       return "no";
    }
    $self->{Logger}->debug("Current Time $curTimeInSec and Override Time: $overrideTimeout");
    for (my $x = 0; $x < @{$jobs};$x++){

       # hack cause we are getting an array of jobs but the first element is not set
       if (!defined(${$jobs}[$x])){
            return "no";
       }

       if ((abs($curTimeInSec - ${$jobs}[$x]->getModificationTime())) < $overrideTimeout){
           return "no";
       }
    }
    return "yes";
}


#
# Builds a hash of jobs where the key is
# the job id and the value in the hash is
# all job objects who share that job id stored
# in an array
# Ex:
#   $hash{"123445"} => {Panfish::Job,Panfish::Job,Panfish::Job};
#
#
sub _buildJobHash {
    my $self = shift;
    my $cluster = shift;
    
    my @jobs = $self->{JobDb}->getJobsByClusterAndState($cluster,
                Panfish::JobState->SUBMITTED());

    if (!@jobs){
            $self->{Logger}->error("Error getting jobs from database");
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


# 
# This function takes two jobs and sorts them
# first by job id and then by task id
# the lower the job id and task id wins 
#
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


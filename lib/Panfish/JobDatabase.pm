package Panfish::JobDatabase;

use strict;
use English;
use warnings;


use Panfish::FileUtil;
use Panfish::FileReaderWriter;
use Panfish::Logger;
use Panfish::ConfigFromFileFactory;
use Panfish::Config;
use Panfish::JobState;
use Panfish::Job;
=head1 SYNOPSIS
   
  Panfish::JobDatabase -- Database to store Jobs

=head1 DESCRIPTION

Database for Jobs using files in the filesystem as the storage
medium.

=head1 METHODS

=head3 new

Creates new instance of JobDatabase

my $logger = Panfish::Logger->new();
my $readerWriter =  Panfish::FileReaderWriterImpl->new($logger);

my $jobDb = Panfish::JobDatabase->new($readerWriter,"/home/foo",$logger);

=cut

sub new {
   my $class = shift;
   my $self = {
     FileReaderWriter  => shift,
     SubmitDir         => shift,
     Logger            => shift,
     FileUtil          => undef,
     ConfigFactory     => undef,
     JOB_NAME_KEY      => "job.name",
     COMMAND_KEY       => "command.to.run",
     CURRENT_DIR_KEY   => "current.working.dir",
     COMMANDS_FILE_KEY => "commands.file",
     PSUB_FILE_KEY     => "psub.file",
     REAL_JOB_ID_KEY   => "real.job.id"
   };
   $self->{FileUtil} = Panfish::FileUtil->new($self->{Logger});
   $self->{ConfigFactory} = Panfish::ConfigFromFileFactory->new($self->{FileReaderWriter},$self->{Logger});
   my $blessedself = bless($self,$class);
   return $blessedself;
}


=head3 getSummaryForCluster

This method returns a human readable string summarizing
The number of jobs in each state for a given cluster

Format of output:

(#) submitted (#) batched (#) batchedandchummed (#) queued (#) running (#) failed (#) deleted (#) done


=cut

sub getSummaryForCluster {
    my $self = shift;
    my $cluster = shift;

    
    # basically get # of files in each directory and report it
    # in a string
    my $outStr = "";
    my @states = Panfish::JobState->getAllStates();
    my $count = 0;
    for (my $x = 0; $x < @states; $x++){
        $count = $self->{FileUtil}->getNumberFilesInDirectory($self->{SubmitDir}.
                                                              "/".$cluster.
                                                              "/".$states[$x]);
        $outStr .= " ($count) $states[$x]";
    }
    
    return $outStr;
}

=head3 insert

Adds a new job to the database returning undef upon success otherwise
a string with the error upon failure.

$jobDb->insert($job);

=cut

sub insert {
   my $self = shift;
   my $job = shift;

   if (!defined($self->{FileReaderWriter})){
     return "FileReaderWriter not defined";
   }

   if (!defined($self->{SubmitDir})){
     return "SubmitDir not set";
   }

   if (!defined($job)){
     return "Job passed in is undefined";
   }

   my $outFile = $self->{SubmitDir}."/".$job->getCluster()."/".
                 $job->getState()."/".
                 $job->getJobId().$self->_getTaskSuffix($job->getTaskId());

   if (defined($self->{Logger})){
     $self->{Logger}->debug("Attempting to insert job by writing to file: $outFile");
   }


   my $res = $self->{FileReaderWriter}->openFile(">$outFile");
   if (defined($res)){
     return $res;
   }

   $self->{FileReaderWriter}->write($self->{CURRENT_DIR_KEY}."=".$job->getCurrentWorkingDir()."\n");
   if (defined($job->getJobName())){
       $self->{FileReaderWriter}->write($self->{JOB_NAME_KEY}."=".$job->getJobName()."\n");
   }
   $self->{FileReaderWriter}->write($self->{COMMAND_KEY}."=".$job->getCommand()."\n");
   if (defined($job->getCommandsFile())){
       $self->{FileReaderWriter}->write($self->{COMMANDS_FILE_KEY}."=".$job->getCommandsFile()."\n");
   }

   if (defined($job->getPsubFile())){
       $self->{FileReaderWriter}->write($self->{PSUB_FILE_KEY}."=".$job->getPsubFile()."\n");
   }
   if (defined($job->getRealJobId())){
       $self->{FileReaderWriter}->write($self->{REAL_JOB_ID_KEY}."=".$job->getRealJobId()."\n");

   }

   $self->{FileReaderWriter}->close();

   return undef;
}



#
# Internal method that creates taskSuffix
# which is .# if the taskid is set otherwise
# an empty string is returned
#
sub _getTaskSuffix {
    my $self = shift;
    my $taskId = shift;
    my $taskSuffix = "";

   #only append task id if its set
   if (defined($taskId) &&
       $taskId ne ""){
       $taskSuffix = ".".$taskId;
   }
   return $taskSuffix;
}


=head3 update

Updates the job in the database

=cut

sub update {
   my $self = shift;
   my $job = shift;
   
   if (!defined($job)){
      return "job is undef";
   }

   # find job in system
   my $oldJob = $self->getJobByClusterAndId($job->getCluster(),$job->getJobId(),$job->getTaskId());
   my $res;
   if (defined($oldJob)){
   
      # is the new job different? if no return
      if ($job->equals($oldJob) == 1){
         $self->{Logger}->debug("Jobs match");
         return undef;
      }
   
      $self->{Logger}->debug("Deleting old job: ".$oldJob->getJobAndTaskId());
      # delete that job
      $res =$self->delete($oldJob);

      if (defined($res)){
         $self->{Logger}->error("Unable to delete old job $res");
         return "Unable to delete old job $res";
      }
   }

   # write out new job
   return $self->insert($job);
}

sub updateArray {
   my $self = shift;
   my $jobArrayRef = shift;

   $self->{Logger}->info(" found ".@{$jobArrayRef}." to update");

   if (!defined($jobArrayRef) || @{$jobArrayRef} <= 0){
      $self->{Logger}->error("No jobs to update");
      return "no jobs to update";
   }
   my $res;
   for (my $x = 0; $x < @{$jobArrayRef}; $x++){
     $self->{Logger}->info("updating ".${$jobArrayRef}[$x]->getJobId().".".${$jobArrayRef}[$x]->getTaskId()); 
     $res = $self->update(${$jobArrayRef}[$x]);
     if (defined($res)){
         return $res;
     }
     
   }

   return undef;
}


=head3 getJobsByClusterAndState

Gets array of jobs from database filtering by cluster and state.  If
there was an error undef is returned otherwise an empty array.

my @job = $jobDb->getJobByClusterAndState("gordon_shadow.q",$state->SUBMITTED());

=cut

sub getJobsByClusterAndState {
    my $self = shift;
    my $cluster = shift;
    my $state = shift;
    my @jobArr;
    my $searchDir = $self->{SubmitDir}."/".$cluster."/".$state;
    
    my @files = $self->{FileUtil}->getFilesInDirectory($searchDir);
    if (!@files){
       return @jobArr;
    }
    my $len = @files;

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Found $len files in search of $searchDir");
    }

    my $curJob;
    for (my $x = 0; $x < @files; $x++){
       $curJob = $self->_getJobFromJobFile($files[$x],$cluster,$state);
       if (!defined($curJob)){
           if (defined($self->{Logger})){
               $self->{Logger}->error("Problem creating job from $files[$x]");
           }
           return undef;
       }
       push(@jobArr,$curJob);
    }
    return @jobArr;
}

=head3 getNumberOfJobsInState

Gets the number of jobs in the state specified

=cut

sub getNumberOfJobsInState {
    my $self = shift;
    my $cluster = shift;
    my $state = shift;

    my $searchDir = $self->{SubmitDir}."/".$cluster."/".$state;

    $self->{Logger}->debug("Searching $searchDir");

    my @files = $self->{FileUtil}->getFilesInDirectory($searchDir);
    if (!@files){
       $self->{Logger}->debug("didnt find any jobs");
       return 0;
    }
    my $len = @files;
    return $len;
}

=head3 getJob

Gets a job from the database if any exist.  This is done
by searching the submit directory (set in the constructor) for
any files matching $JOBID.$TASKID.  When found the job object is
constructed by reading the contents of the file and looking at
which sub directory the file resides in.  This sub directory denotes
the state of the job.

my $job = $jobDb->getJobByClusterAndId("gordon_shadow.q","123",1");


=cut

sub getJobByClusterAndId {
   my $self = shift;
   my $cluster = shift;
   my $jobId = shift;
   my $taskId = shift;


   my $jobFileName = "$jobId".$self->_getTaskSuffix($taskId);
   my $searchDir = $self->{SubmitDir}."/".$cluster;
   if (defined($self->{Logger})){
      $self->{Logger}->debug("Looking for job: $jobFileName under $searchDir");
   } 
   
   my $jobFile = $self->{FileUtil}->findFile($searchDir,$jobFileName,Panfish::JobState->KILL());
   if (!defined($jobFile)){
     return undef;
   }

   return $self->_getJobFromJobFile($jobFile,$cluster);
}

=head3 getJobByClusterAndStateAndId

Given cluster, state, and job id/task return the job.  
In some implementations knowing the state will speed
up the search.

=cut

sub getJobByClusterAndStateAndId {
    my $self = shift;
    my $cluster = shift;
    my $state = shift;
    my $jobId = shift;
    my $taskId = shift;


    my $jobFileName = "$jobId".$self->_getTaskSuffix($taskId);
    my $searchDir = $self->{SubmitDir}."/".$cluster."/".$state;
    if (defined($self->{Logger})){
       $self->{Logger}->debug("Looking for job: $jobFileName under $searchDir");
    }

    my $jobFile = $self->{FileUtil}->findFile($searchDir,$jobFileName,Panfish::JobState->KILL());
    if (!defined($jobFile)){
       return undef;
    }

    return $self->_getJobFromJobFile($jobFile,$cluster);
}


#
# Gets a job object from a job file
#
sub _getJobFromJobFile {
    my $self = shift;
    my $jobFile = shift;
    my $cluster = shift;
    my $state = shift;
    my $jobId = undef;
    my $taskId = undef;


    my $config = $self->{ConfigFactory}->getConfig($jobFile);
    if (!defined($config)){
        if (defined($self->{Logger})){
            $self->{Logger}->error("Unable to load config for file $jobFile");
        }
        return undef;
    }

    if ($jobFile=~/^.*\/([0-9]+)$/){
       $jobId = $1;
       $taskId = "";
    }
    elsif ($jobFile=~/^.*\/([0-9]+)\.([0-9]+)$/){
       $jobId = $1;
       $taskId = $2;
    }

    if (!defined($state)){
        $state = $jobFile;
        $state =~s/^$self->{SubmitDir}\/$cluster\///;

        $state =~s/\/.*$//;
    }

       
   $self->{Logger}->debug("Job $jobId.$taskId in cluster $cluster in state $state");

   return Panfish::Job->new($cluster,$jobId,$taskId,
                            $config->getParameterValue($self->{JOB_NAME_KEY}),
                            $config->getParameterValue($self->{CURRENT_DIR_KEY}),
                            $config->getParameterValue($self->{COMMAND_KEY}),$state,
                            $self->{FileUtil}->getModificationTimeOfFile($jobFile),
                            $config->getParameterValue($self->{COMMANDS_FILE_KEY}),
                            $config->getParameterValue($self->{PSUB_FILE_KEY}),
                            $config->getParameterValue($self->{REAL_JOB_ID_KEY}));
}


=head3 delete

Deletes the job by physically removing it from the database.
Returns undef for success otherwise a message upon failure.

$job = Panfish::Job->new();
$jobdb->delete($job);

=cut

sub delete {
   my $self = shift;
   my $job = shift;
   
   if (!defined($job)){
      return "No job passed in";
   }
 
   $self->{Logger}->debug("Deleting ".$self->{SubmitDir}."/".
                                           $job->getCluster()."/".
                                           $job->getState()."/".
                                           $job->getJobAndTaskId());
 
   my $res = $self->{FileUtil}->deleteFile($self->{SubmitDir}."/".
                                           $job->getCluster()."/".
                                           $job->getState()."/".
                                           $job->getJobAndTaskId());

   if ($res != 1){
       return "Unable to delete job $!";
   }
 
   return undef;
}


=head3 kill

Kills the job.  This tells everyone that the job processing
should be killed and no further work is to be done on the job.

=cut

sub kill {
    my $self = shift;
    my $job = shift;

    if (!defined($self->{FileReaderWriter})){
        return "FileReaderWriter not defined";
    }

    if (!defined($self->{SubmitDir})){
        return "SubmitDir not set";
    }

    if (!defined($job)){
        return "Job passed in is undefined";
    }

    
    my $outFile = $self->{SubmitDir}."/".$job->getCluster()."/".
                  Panfish::JobState->KILL()."/".
                  $job->getJobId().$self->_getTaskSuffix($job->getTaskId());

    if (defined($self->{Logger})){
        $self->{Logger}->debug("Attempting to kill job by writing to file: $outFile");
    }


   my $res = $self->{FileReaderWriter}->openFile(">$outFile");
   if (defined($res)){
     return $res;
   }

   $self->{FileReaderWriter}->write($self->{CURRENT_DIR_KEY}."=".$job->getCurrentWorkingDir()."\n");
   $self->{FileReaderWriter}->write($self->{JOB_NAME_KEY}."=".$job->getJobName()."\n");
   $self->{FileReaderWriter}->write($self->{COMMAND_KEY}."=".$job->getCommand()."\n");
   $self->{FileReaderWriter}->close();

   return undef;
}

1;

__END__


=head1 AUTHOR

Panfish::JobDatabase is written by Christopher Churas<churas@ncmir.ucsd.edu>

=cut

